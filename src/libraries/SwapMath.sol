// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
 
import { InternalMath } from "./InternalMath.sol";
import { SafeCast } from "./SafeCast.sol";

library SwapMath {
    using SafeCast for uint256;

    function computeSwapStep(
        uint160 _sqrtPriceCurrentX96,
        uint160 _sqrtPriceTargetX96,
        uint256 _liquidity,
        uint256 _amountRemaining
    ) internal pure returns (uint160 nextCalculatedSqrtPriceX96, uint256 amountIn, uint256 amountOut) {
        bool direction = _sqrtPriceCurrentX96 > _sqrtPriceTargetX96; // means that we want to sell TokenX

        nextCalculatedSqrtPriceX96 = InternalMath.getNextSqrtPriceBasedOnInput(
            _sqrtPriceCurrentX96, _liquidity, _amountRemaining, direction);
        
        amountIn = InternalMath.calculateDeltaToken0(
            _sqrtPriceCurrentX96, nextCalculatedSqrtPriceX96, _liquidity);

        amountOut = InternalMath.calculateDeltaToken1(
            _sqrtPriceCurrentX96, nextCalculatedSqrtPriceX96, _liquidity);
        
        // If the swap was declares as BUY position (FOR ETH FOR EXAMPLE)
        if (!direction) (amountIn, amountOut) = (amountOut, amountIn);
    }
}
