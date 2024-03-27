// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { mulDiv } from "@prb-math/contracts/Common.sol";
import { FixedPoint96 } from "./FixedPoints.sol";
import { SafeCast } from "./SafeCast.sol";

library InternalMath {
    using SafeCast for uint256;

    error InternalMath__Overflow();

    function getNextSqrtPriceBasedOnInput(
        uint160 _currentSqrtPriceX96,
        uint256 _liquidity,
        uint256 _amountRemaining,
        bool direction
    ) internal pure returns (uint160 nextCalculatedSqrtPriceX96) {
        nextCalculatedSqrtPriceX96 = direction
            ? getNextPriceSqrtX96OnAmount0RoundingUp(
                _currentSqrtPriceX96,
                _liquidity,
                _amountRemaining
            )
            : getNextPriceSqrtX96OnAmount1RoundingUp(
                _currentSqrtPriceX96,
                _liquidity,
                _amountRemaining
            );
    }

    /// @notice when we want to sell tokenX and direction is true.
    function getNextPriceSqrtX96OnAmount0RoundingUp(uint160 _sqrtPriceX96, uint256 _liquidity, uint256 _amount)
        internal
        pure
        returns(uint160 nextPriceSqrtX96)
    {
        uint256 liquidity = _liquidity >> FixedPoint96.RESOLUTION;

        uint256 numenator = tryMul(liquidity, _sqrtPriceX96); //@audit It's slightly Overflow vulnerable | Confident: LOW
        
        uint256 product = tryMul(_amount,_sqrtPriceX96);

        uint256 denominator = tryAdd(product, liquidity);

        uint256 nextPriceSqrtX96 = mulDivRoundingUp(_sqrtPriceX96, liquidity, numenator + _liquidity).toUint160();
    }   

    function getNextPriceSqrtX96OnAmount1RoundingUp(uint160 _sqrtPriceX96, uint256 _liquidity, uint256 _amount)
        internal
        pure
        returns(uint160 nextPriceSqrtX96)
    {
        // Next implementation...
    }

    function calculateDeltaToken0(uint160 _currentSqrtPriceX96, uint160 _nextSqrtPriceX96, uint256 _liquidity)
        internal
        pure
        returns (uint256 result_amount)
    {

    }

    function calculateDeltaToken1(uint160 _currentSqrtPriceX96, uint160 _nextSqrtPriceX96, uint256 _liquidity)
        internal
        pure
        returns (uint256 result_amount)
    {

    }

    function mulDivRoundingUp(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        result = mulDiv(a, b, denominator);
        if (mulmod(a, b, denominator) > 0) {
            require(result < type(uint256).max);
            result++;
        }
    }

    function divRoundingUp(uint256 numerator, uint256 denominator)
        internal
        pure
        returns (uint256 result)
    {
        assembly {
            result := add(
                div(numerator, denominator),
                gt(mod(numerator, denominator), 0)
            )
        }
    }

    function tryAdd(uint256 a, uint256 b) internal pure returns (uint256 result) {
        unchecked {
            uint256 c = a + b;
            if (c < a) revert InternalMath__Overflow();
            return c;
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an success flag (no overflow).
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (uint256 result) {
        unchecked {
            if (a == 0) return 0;
            uint256 c = a * b;
            if (c / a != b) revert InternalMath__Overflow();
            return c;
        }
    }

}
