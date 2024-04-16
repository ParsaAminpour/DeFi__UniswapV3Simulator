// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {InternalMath} from "./InternalMath.sol";
import {SafeCast} from "./SafeCast.sol";

library SwapMath {
    using SafeCast for uint256;

    /// @notice this is where we calculate swap amounts and this is also where we’ll calculate and subtract swap fees.
    /// @dev This is the core logic of swapping. The function calculates swap amounts within one price range and respecting available liquidity.
    /// @dev It’ll return: the new current price and input and output token amounts. Even though the input amount is provided by the user,
    ///     we still calculate it to know how much of the user-specified input amount was processed by one call to computeSwapStep

    function computeSwapStep(
        uint160 _sqrtPriceCurrentX96,
        uint160 _sqrtPriceTargetX96,
        uint128 _liquidity,
        uint256 _amountRemaining,
        uint24 fee
    ) internal pure returns (uint160 nextCalculatedSqrtPriceX96, uint256 amountIn, uint256 amountOut, uint256 feeAmount) {
        bool direction = _sqrtPriceCurrentX96 >= _sqrtPriceTargetX96; // means that we want to sell TokenX

        uint256 amountRemainingLessFee = InternalMath.mulDivision(
            _amountRemaining, 1e6 - fee, 1e6
        );

        amountIn = direction
            ? InternalMath.calculateDeltaToken0(_sqrtPriceCurrentX96, _sqrtPriceTargetX96, _liquidity, true)
            : InternalMath.calculateDeltaToken1(_sqrtPriceCurrentX96, _sqrtPriceTargetX96, _liquidity, true);

        /// If it’s smaller than amountRemaining, we say that the current price range cannot fulfill the whole swap
        nextCalculatedSqrtPriceX96 = (amountRemainingLessFee >= amountIn)
            ? _sqrtPriceTargetX96
            : nextCalculatedSqrtPriceX96 =
                InternalMath.getNextSqrtPriceBasedOnInput(_sqrtPriceCurrentX96, _liquidity, amountRemainingLessFee, direction);

        bool fulfilled = nextCalculatedSqrtPriceX96 == _sqrtPriceTargetX96;

        if (direction) {
            amountIn = fulfilled
                ? amountIn
                : InternalMath.calculateDeltaToken0(_sqrtPriceCurrentX96, nextCalculatedSqrtPriceX96, _liquidity, true);

            amountOut = InternalMath.calculateDeltaToken1(_sqrtPriceCurrentX96, nextCalculatedSqrtPriceX96, _liquidity, false);
        } else {
            amountIn = fulfilled
                ? amountIn
                : InternalMath.calculateDeltaToken1(_sqrtPriceCurrentX96, nextCalculatedSqrtPriceX96, _liquidity, true);

                amountOut = InternalMath.calculateDeltaToken0(_sqrtPriceCurrentX96, nextCalculatedSqrtPriceX96, _liquidity, false);
        }

        feeAmount = fulfilled 
            ? InternalMath.mulDivRoundingUp(amountIn, fee, 1e6 - fee)
            : _amountRemaining - amountIn;

        // If the swap was declares as BUY position (FOR ETH FOR EXAMPLE)
        if (!direction) (amountIn, amountOut) = (amountOut, amountIn);
    }
}
