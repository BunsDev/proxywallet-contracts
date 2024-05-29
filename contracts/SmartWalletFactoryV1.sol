//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./interfaces/ISmartWalletFactory.sol";
import "./SmartWalletV1.sol";

contract SmartWalletFactoryV1 is ISmartWalletFactory {
    address public immutable implementation;

    mapping(address => bytes32) public deployedSalts;

    CommonDeployParams public commonDeployParams;
    uint256 public counter;

    struct CommonDeployParams {
        address linkToken;
        address clRegistrar;
        address clRegistry;
        address uniswapV3Router;
        address wethToken;
        bytes wethToLinkSwapPath;
    }

    constructor(
        CommonDeployParams memory _commonDeployParams,
        address _implementation
    ) {
        implementation = _implementation;
        commonDeployParams = _commonDeployParams;
    }

    function createWallet(
        address owner,
        address allowlistOperator
    ) external returns (address) {
        return
            create2Wallet(
                owner,
                allowlistOperator,
                keccak256(abi.encodePacked(counter++))
            );
    }

    function create2Wallet(
        address owner,
        address allowlistOperator,
        bytes32 salt
    ) public returns (address) {
        SmartWalletV1 wallet = SmartWalletV1(
            payable(Clones.cloneDeterministic(implementation, salt))
        );
        wallet.initialize(
            CreateWalletParams({
                owner: owner,
                allowlistOperator: allowlistOperator,
                linkToken: commonDeployParams.linkToken,
                clRegistrar: commonDeployParams.clRegistrar,
                clRegistry: commonDeployParams.clRegistry,
                uniswapV3Router: commonDeployParams.uniswapV3Router,
                wethToken: commonDeployParams.wethToken,
                wethToLinkSwapPath: commonDeployParams.wethToLinkSwapPath
            })
        );

        deployedSalts[address(wallet)] = salt;

        return address(wallet);
    }

    function predictCreate2Wallet(
        bytes32 salt
    ) external view returns (address) {
        return
            Clones.predictDeterministicAddress(
                implementation,
                salt,
                address(this)
            );
    }

    function validateWallet(address wallet) external view returns (bool) {
        address expectedAddress = Clones.predictDeterministicAddress(
            implementation,
            deployedSalts[wallet],
            address(this)
        );
        return expectedAddress == wallet;
    }
}
