//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.23;

import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./libraries/EnumerableMap.sol";
import "./libraries/UniswapV3Actions.sol";
import "./interfaces/IWeth.sol";
import "./interfaces/IAutoExecuteCallback.sol";
import "./interfaces/IAutomationRegistrarInterface.sol";
import "./interfaces/IAutomationRegistryInterface.sol";
import "./interfaces/ISmartWallet.sol";
import "./interfaces/ISmartWalletFactory.sol";

import "hardhat/console.sol";

contract SmartWalletV1 is
    OwnableUpgradeable,
    EIP712Upgradeable,
    NoncesUpgradeable,
    ISmartWallet
{
    using EnumerableMap for EnumerableMap.UintToAutoExecuteMap;
    using Address for address;

    bytes32 private constant ADD_TO_ALLOWLIST_PERMIT_TYPEHASH =
        keccak256(
            "AddToAllowlistPermit(address newAllowlist,uint256 nonce,uint256 deadline)"
        );

    uint256 constant LINK_FEE_PER_AUTOEXECUTE = 0.1 * 10 ** 18;
    uint32 constant AUTOEXECUTE_GAS_LIMIT = 5_000_000;

    mapping(address => bool) public allowlist;
    mapping(address => mapping(bytes4 => bool)) public blacklistedFunctions;
    mapping(bytes32 => uint256) public extenralIdsToExecutesIds;

    address public allowListOperator;
    uint256 public autoExecuteCounter;
    uint256 public upkeepId;

    address private linkToken;
    address private clRegistrar;
    address private clRegistry;

    EnumerableMap.UintToAutoExecuteMap private autoExecutesMap;

    address private uniswapV3Router;
    address private wethToken;
    bytes private wethToLinkSwapPath;

    modifier onlyAllowlist() {
        require(allowlist[msg.sender], "SW: not in allowlist");
        _;
    }

    modifier onlyAllowlistOperator() {
        require(msg.sender == allowListOperator, "SW: not an operator");
        _;
    }

    constructor() {
        _disableInitializers();
    }

    receive() external payable {}

    function initialize(
        ISmartWalletFactory.CreateWalletParams calldata createParams
    ) external initializer {
        __Ownable_init(createParams.owner);
        __EIP712_init("SmartWalletV1", "1");

        allowListOperator = createParams.allowlistOperator;
        uniswapV3Router = createParams.uniswapV3Router;
        wethToken = createParams.wethToken;
        wethToLinkSwapPath = createParams.wethToLinkSwapPath;

        linkToken = createParams.linkToken;
        clRegistrar = createParams.clRegistrar;
        clRegistry = createParams.clRegistry;
    }

    function execute(
        address to,
        uint256 callValue,
        bytes calldata data
    ) public onlyOwner returns (bytes memory returnData) {
        require(to != address(this), "SW: to cannot be this");
        returnData = _execute(to, callValue, data);
    }

    function executeBatch(
        address[] calldata tos,
        uint256[] calldata callValues,
        bytes[] calldata datas
    ) public onlyOwner returns (bytes[] memory returnDatas) {
        require(
            tos.length == callValues.length && tos.length == datas.length,
            "SW: mismatch arrays"
        );
        returnDatas = new bytes[](tos.length);
        for (uint i = 0; i < tos.length; i++) {
            returnDatas[i] = _execute(tos[i], callValues[i], datas[i]);
        }
    }

    function blacklist(address to, bytes4 funcSelector) external onlyAllowlist {
        require(funcSelector != bytes4(0), "SW: invalid selector");
        blacklistedFunctions[to][funcSelector] = true;
    }

    function removeFromBlacklist(
        address to,
        bytes4 funcSelector
    ) external onlyAllowlist {
        blacklistedFunctions[to][funcSelector] = false;
    }

    function blacklistBatch(
        address[] calldata tos,
        bytes4[] calldata funcSelectors
    ) external onlyAllowlist {
        require(tos.length == funcSelectors.length, "SW: mismatch arrays");
        for (uint i; i < tos.length; i++) {
            require(funcSelectors[i] != bytes4(0), "SW: invalid selector");
            blacklistedFunctions[tos[i]][funcSelectors[i]] = true;
        }
    }

    function removeFromBlacklistBatch(
        address[] calldata tos,
        bytes4[] calldata funcSelectors
    ) external onlyAllowlist {
        require(tos.length == funcSelectors.length, "SW: mismatch arrays");
        for (uint i; i < tos.length; i++) {
            blacklistedFunctions[tos[i]][funcSelectors[i]] = false;
        }
    }

    function addToAutoExecute(
        bytes32 id,
        address callback,
        bytes calldata executeData,
        address executeTo,
        uint256 executeValue,
        uint256 executeAfter
    ) external {
        require(
            msg.sender == owner() || allowlist[msg.sender],
            "SW: invalid sender"
        );

        require(executeAfter > block.timestamp, "SW: invalid execute time");
        require(extenralIdsToExecutesIds[id] == 0, "SW: id already exist");

        _fundClUpkeep(LINK_FEE_PER_AUTOEXECUTE);

        AutoExecute memory data = AutoExecute({
            id: id,
            creator: msg.sender,
            callback: callback,
            executeData: executeData,
            executeTo: executeTo,
            executeValue: executeValue,
            executeAfter: executeAfter
        });

        uint256 internalId = ++autoExecuteCounter;
        extenralIdsToExecutesIds[id] = internalId;
        autoExecutesMap.set(internalId, data);
    }

    function removeAutoExecute(bytes32 id) external {
        uint256 internalId = extenralIdsToExecutesIds[id];
        require(internalId > 0, "SW: not exist");
        AutoExecute memory data = autoExecutesMap.get(internalId);
        require(data.creator == msg.sender, "SW: invalid sender");
        autoExecutesMap.remove(internalId);
    }

    function addToAllowlistWithPermit(
        address addr,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        require(deadline >= block.timestamp, "SW: expired signature");

        bytes32 structHash = keccak256(
            abi.encode(
                ADD_TO_ALLOWLIST_PERMIT_TYPEHASH,
                addr,
                _useNonce(allowListOperator),
                deadline
            )
        );

        bytes32 hash = _hashTypedDataV4(structHash);

        address signer = ECDSA.recover(hash, v, r, s);
        require(signer == allowListOperator, "SW: invalid signer");

        allowlist[addr] = true;
    }

    function addToAllowlist(address addr) public onlyAllowlistOperator {
        allowlist[addr] = true;
    }

    function removeFromAllowlist(address addr) public onlyAllowlistOperator {
        allowlist[addr] = false;
    }

    function performUpkeep(bytes calldata performData) external {
        uint256 id = abi.decode(performData, (uint256));
        AutoExecute memory data = autoExecutesMap.get(id);
        require(block.timestamp > data.executeAfter, "SW: to early to execute");

        _executeUpkeep(data);
        autoExecutesMap.remove(id);
    }

    function checkUpkeep(
        bytes calldata
    ) external view returns (bool upkeepNeeded, bytes memory performData) {
        uint256[] memory keys = autoExecutesMap.keys();

        for (uint i; i < keys.length; i++) {
            uint256 key = keys[i];
            AutoExecute memory data = autoExecutesMap.get(key);

            if (block.timestamp > data.executeAfter)
                return (true, abi.encode(key));
        }
    }

    function _execute(
        address to,
        uint256 callValue,
        bytes calldata data
    ) private returns (bytes memory returnData) {
        require(to != address(this), "SW: to cannot be this");

        _requireNotBlaclisted(to, data);

        if (data.length > 0) {
            returnData = to.functionCallWithValue(data, callValue);
        } else {
            Address.sendValue(payable(to), callValue);
        }
    }

    function _fundClUpkeep(uint256 amountLink) private {
        uint256 linkBalance = IERC20(linkToken).balanceOf(address(this));

        if (linkBalance < amountLink) {
            UniswapV3Actions.swapExactOutput(
                uniswapV3Router,
                wethToLinkSwapPath,
                address(this),
                amountLink,
                address(this).balance // FIXME
            );
        }

        IERC20(linkToken).approve(address(clRegistrar), amountLink);

        if (upkeepId == 0) {
            RegistrationParams memory params = RegistrationParams({
                name: "",
                encryptedEmail: "",
                upkeepContract: address(this),
                gasLimit: AUTOEXECUTE_GAS_LIMIT,
                adminAddress: address(this),
                triggerType: 0,
                checkData: "",
                triggerConfig: "",
                offchainConfig: "",
                amount: uint96(LINK_FEE_PER_AUTOEXECUTE)
            });

            upkeepId = IAutomationRegistrarInterface(clRegistrar)
                .registerUpkeep(params);
        } else {
            IAutomationRegistryInterface(clRegistry).addFunds(
                upkeepId,
                uint96(amountLink)
            );
        }
    }

    function _executeUpkeep(AutoExecute memory upkeepData) private {
        if (upkeepData.executeData.length > 0) {
            upkeepData.executeTo.functionCallWithValue(
                upkeepData.executeData,
                upkeepData.executeValue
            );
        } else {
            Address.sendValue(
                payable(upkeepData.executeTo),
                upkeepData.executeValue
            );
        }

        if (upkeepData.callback != address(0)) {
            upkeepData.callback.functionCall(
                abi.encodeCall(
                    IAutoExecuteCallback(upkeepData.callback)
                        .autoExecuteCallback,
                    (upkeepData.id)
                )
            );
        }
    }

    function _requireNotBlaclisted(
        address to,
        bytes calldata data
    ) private view {
        if (data.length == 0) {
            return;
        }

        bytes4 selector = bytes4(data[:4]);
        require(!blacklistedFunctions[to][selector], "CW: func is blaclisted");
    }
}
