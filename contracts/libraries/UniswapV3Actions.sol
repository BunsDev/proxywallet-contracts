// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../interfaces/IUniswapRouterV3.sol";

library UniswapV3Actions {
    function swap(
        address _router,
        bytes memory _path,
        address _recipient,
        uint256 _amount
    ) internal returns (uint256 amountOut) {
        IUniswapRouterV3.ExactInputParams memory swapParams = IUniswapRouterV3
            .ExactInputParams({
                path: _path,
                recipient: _recipient,
                amountIn: _amount,
                amountOutMinimum: 0
            });
        return IUniswapRouterV3(_router).exactInput{value: _amount}(swapParams);
    }

    function swapExactOutput(
        address _router,
        bytes memory _path,
        address _recipient,
        uint256 _amountOut,
        uint256 _amountInMaximum
    ) internal returns (uint256 amountIn) {
        IUniswapRouterV3.ExactOutputParams memory swapParams = IUniswapRouterV3
            .ExactOutputParams({
                path: _path,
                recipient: _recipient,
                amountOut: _amountOut,
                amountInMaximum: _amountInMaximum
            });
        amountIn = IUniswapRouterV3(_router).exactOutput{
            value: _amountInMaximum
        }(swapParams);
        IUniswapRouterV3(_router).refundETH();
    }
}
