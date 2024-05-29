// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IAutomationCompatible.sol";

interface ISmartWallet is IAutomationCompatible {
    struct AutoExecute {
        bytes32 id;
        address creator;
        address callback;
        bytes executeData;
        address executeTo;
        uint256 executeValue;
        uint256 executeAfter;
    }

    function blacklist(address to, bytes4 funcSelector) external;

    function removeFromBlacklist(address to, bytes4 funcSelector) external;

    function blacklistBatch(
        address[] calldata tos,
        bytes4[] calldata funcSelectors
    ) external;

    function removeFromBlacklistBatch(
        address[] calldata tos,
        bytes4[] calldata funcSelectors
    ) external;

    function addToAutoExecute(
        bytes32 id,
        address callback,
        bytes calldata executeData,
        address executeTo,
        uint256 executeValue,
        uint256 executeAfter
    ) external returns (bytes32);

    function removeAutoExecute(bytes32 id) external;

    function addToAllowlistWithPermit(
        address addr,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function addToAllowlist(address addr) external;

    function removeFromAllowlist(address addr) external;

    function execute(
        address to,
        uint256 callValue,
        bytes calldata data
    ) external returns (bytes memory returnData);

    function executeBatch(
        address[] calldata tos,
        uint256[] calldata callValues,
        bytes[] calldata datas
    ) external returns (bytes[] memory returnDatas);
}
