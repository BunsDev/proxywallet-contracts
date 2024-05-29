// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAutomationCompatible {
    function checkUpkeep(
        bytes calldata
    ) external view returns (bool, bytes memory);

    function performUpkeep(bytes calldata) external;
}
