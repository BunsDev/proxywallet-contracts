//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.23;

import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
// import "@chainlink/contracts/src/v0.8/.sol";
import "./libraries/EnumerableMap.sol";
import "./libraries/UniswapV3Actions.sol";
import "./interfaces/IWeth.sol";
import "./interfaces/IAutoExecuteCallback.sol";
import "./interfaces/IAutomationRegistrarInterface.sol";
import "./interfaces/IAutomationRegistryInterface.sol";
import "./structs/CreateWalletParams.sol";

contract SmartWalletV1 is OwnableUpgradeable {
    using EnumerableMap for EnumerableMap.UintToAutoExecuteMap;
    using Address for address;

    uint256 constant LINK_FEE_PER_AUTOEXECUTE = 0.1e18;
    uint32 constant AUTOEXECUTE_GAS_LIMIT = 5_000_000;

    mapping(address => bool) public allowlist;
    mapping(address => mapping(bytes4 => bool)) public blacklistedFunctions;
    EnumerableMap.UintToAutoExecuteMap autoExecutesMap;
    address public allowListOperator;

    address public linkToken;
    address public clRegistrar;
    address public clRegistry;
    uint256 public upkeepId;

    address public uniswapV3Router;
    address public wethToken;
    bytes public wethToLinkSwapPath;

    uint256 public autoExecuteCounter;

    modifier onlyAllowlist() {
        require(allowlist[msg.sender], "SW: not a blacklister");
        _;
    }

    modifier onlyAllowlistOperator() {
        require(msg.sender == allowListOperator, "SW: not an operator");
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        CreateWalletParams calldata createParams
    ) external initializer {
        __Ownable_init(createParams.owner);

        allowListOperator = createParams.allowlistOperator;
        uniswapV3Router = createParams.uniswapV3Router;
        wethToken = createParams.wethToken;
        wethToLinkSwapPath = createParams.wethToLinkSwapPath;

        linkToken = createParams.linkToken;
        clRegistrar = createParams.clRegistrar;
        clRegistry = createParams.clRegistry;

        for (uint i; i < createParams.initAllowlist.length; i++) {
            allowlist[createParams.initAllowlist[i]] = true;
        }
    }

    function blacklist(
        address[] calldata tos,
        bytes4[] calldata funcSelectors
    ) external onlyAllowlist {
        require(tos.length == funcSelectors.length, "SW: mismatch arrays");
        for (uint i; i < tos.length; i++) {
            blacklistedFunctions[tos[i]][funcSelectors[i]] = true;
        }
    }

    function removeFromBlacklist(
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

        autoExecutesMap.set(++autoExecuteCounter, data);
    }

    function _fundClUpkeep(uint256 amountLink) private {
        uint256 linkBalance = IERC20(linkToken).balanceOf(address(this));

        if (linkBalance < amountLink) {
            IWETH(wethToken).deposit{value: address(this).balance}();

            uint256 amountIn = UniswapV3Actions.swapExactOutput(
                uniswapV3Router,
                wethToLinkSwapPath,
                address(this),
                amountLink - linkBalance,
                0
            );

            IWETH(wethToken).withdraw(amountIn);
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

    function addToAllowlist(address addr) public onlyAllowlistOperator {
        allowlist[addr] = true;
    }

    function removeFromAllowlist(address addr) public onlyAllowlistOperator {
        allowlist[addr] = false;
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
            require(tos[i] != address(this), "SW: to cannot be this");
            returnDatas[i] = _execute(tos[i], callValues[i], datas[i]);
        }
    }

    function checkUpkeep(
        bytes calldata
    ) external view returns (bool upkeepNeeded, bytes memory performData) {
        uint256[] memory keys = autoExecutesMap.keys();

        for (uint i; i < keys.length; i++) {
            uint256 key = keys[i];
            AutoExecute memory data = autoExecutesMap.get(key);

            if (data.executeAfter >= block.timestamp)
                return (true, abi.encode(data.id));
        }
    }

    function performUpkeep(bytes calldata performData) external {
        uint256 id = abi.decode(performData, (uint256));
        AutoExecute memory data = autoExecutesMap.get(id);
        require(
            data.executeAfter >= block.timestamp,
            "SW: to early to execute"
        );

        _executeUpkeep(data);
        autoExecutesMap.remove(id);
    }

    function _execute(
        address to,
        uint256 callValue,
        bytes calldata data
    ) private returns (bytes memory) {
        _requireNotBlaclisted(to, data);
        return to.functionCallWithValue(data, callValue);
    }

    function _executeUpkeep(AutoExecute memory upkeepData) private {
        upkeepData.executeTo.functionCallWithValue(
            upkeepData.executeData,
            upkeepData.executeValue
        );

        upkeepData.executeTo.functionCallWithValue(
            upkeepData.executeData,
            upkeepData.executeValue
        );

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
        bytes4 selector = bytes4(data[:4]);
        require(!blacklistedFunctions[to][selector], "CW: func is blaclisted");
    }
}
