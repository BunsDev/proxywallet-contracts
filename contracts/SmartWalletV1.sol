//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.23;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
// import "@chainlink/contracts/src/v0.8/.sol";
import "./libraries/EnumerableMap.sol";

import "hardhat/console.sol";

contract SmartWalletV1 is OwnableUpgradeable {
    using EnumerableMap for EnumerableMap.UintToAutoExecuteMap;

    mapping(address => bool) public allowlist;
    mapping(address => mapping(bytes4 => bool)) public blacklistedFunctions;
    EnumerableMap.UintToAutoExecuteMap autoExecutesMap;
    uint256 public autoExecuteCounter;

    modifier onlyAllowlist() {
        require(allowlist[msg.sender], "SW: not a blacklister");
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _owner,
        address[] calldata _initialAllowList
    ) external initializer {
        __Ownable_init(_owner);

        for (uint i; i < _initialAllowList.length; i++) {
            allowlist[_initialAllowList[i]] = true;
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

        AutoExecute memory data = AutoExecute({
            id: ++autoExecuteCounter,
            creator: msg.sender,
            callback: callback,
            executeData: executeData,
            executeTo: executeTo,
            executeValue: executeValue,
            executeAfter: executeAfter
        });

        autoExecutesMap.set(data.id, data);
    }

    function addToAllowlist(address addr) public onlyOwner {
        allowlist[addr] = true;
    }

    function removeFromAllowlist(address addr) public onlyOwner {
        allowlist[addr] = false;
    }

    function execute(
        address to,
        uint256 callValue,
        bytes calldata data
    ) public onlyOwner returns (bytes memory returnData) {
        require(to != address(this), "SW: to cannot be this");
        returnData = Address.functionCallWithValue(to, data, callValue);
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
            returnDatas[i] = Address.functionCallWithValue(
                tos[i],
                datas[i],
                callValues[i]
            );
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

    function _executeUpkeep(AutoExecute memory upkeepData) private {}
}
