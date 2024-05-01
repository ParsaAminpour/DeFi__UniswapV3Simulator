// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {mulDiv} from "@prb-math/contracts/Common.sol";
import {FixedPoint96} from "./FixedPoints.sol";
import {SafeCast} from "./SafeCast.sol";

library InternalMath {
    using SafeCast for uint256;

    error InternalMath__Overflow();
    error InternalMath__DivisionByZero();
    error InternalMath__bIsGreaterThanA();
    error InternalMath__MulDivOverflow(uint256 x, uint256 y, uint256 denominator);

    /// @notice the function calculates a sqrt(P) given another sqrt(P), liquidity, and input amount.
    ///     It tells what the price will be after swapping the specified input amount of tokens, given the current price and liquidity.
    /// @dev calculations:
    ///     price_next = int((liq * q96 * sqrtp_cur) // (liq * q96 + amount_in * sqrtp_cur))  |  amount_in := token0
    ///     price_next = sqrtp_cur + (amount_in * q96) // liq  |  amount_in := token1
    function getNextSqrtPriceBasedOnInput(
        uint160 _currentSqrtPriceX96,
        uint256 _liquidity,
        uint256 _amountRemaining,
        bool direction
    ) internal pure returns (uint160 nextCalculatedSqrtPriceX96) {
        nextCalculatedSqrtPriceX96 = direction
            ? getNextPriceSqrtX96OnAmount0RoundingUp(_currentSqrtPriceX96, _liquidity, _amountRemaining)
            : getNextPriceSqrtX96OnAmount1RoundingUp(_currentSqrtPriceX96, _liquidity, _amountRemaining);
    }

    /// @notice when we want to sell tokenX and direction is true.
    function getNextPriceSqrtX96OnAmount0RoundingUp(uint160 _sqrtPriceX96, uint256 _liquidity, uint256 _amount)
        internal
        pure
        returns (uint160 nextPriceSqrtX96)
    {
        uint256 liquidity = _liquidity << FixedPoint96.RESOLUTION;

        uint256 product = tryMul(_amount, _sqrtPriceX96);
        // Check for Overflow
        if (product / _amount == _sqrtPriceX96) {
            uint256 denominator = tryAdd(product, liquidity);
            nextPriceSqrtX96 = mulDivRoundingUp(_sqrtPriceX96, liquidity, denominator).toUint160();
        } else {
            // If overflow happened this equation will be used but less accurate and precise.
            nextPriceSqrtX96 = divRoundingUp(liquidity, _amount + tryDiv(liquidity, _sqrtPriceX96)).toUint160();
        }
    }

    function getNextPriceSqrtX96OnAmount1RoundingUp(uint160 _sqrtPriceX96, uint256 _liquidity, uint256 _amount)
        internal
        pure
        returns (uint160 nextPriceSqrtX96)
    {
        uint256 amount = _amount << FixedPoint96.RESOLUTION;
        uint160 delta_sqrt = tryDiv(amount, _liquidity).toUint160();
        nextPriceSqrtX96 = tryAdd(_sqrtPriceX96, delta_sqrt).toUint160();
    }

    ///////////////////////////////////
    ///   Calculation Mathematical  ///
    ///////////////////////////////////
    // @audit these three functions have not been audited
    function calculateDeltaToken0(
        uint160 sqrtPriceAX96,
        uint160 sqrtPriceBX96,
        uint128 liquidity,
        bool roundUp
    ) internal pure returns (uint256 amount0) {
        if (sqrtPriceAX96 > sqrtPriceBX96)
            (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);

        require(sqrtPriceAX96 > 0);

        uint256 numerator1 = uint256(liquidity) << FixedPoint96.RESOLUTION;
        uint256 numerator2 = sqrtPriceBX96 - sqrtPriceAX96;

        if (roundUp) {
            amount0 = divRoundingUp(
                mulDivRoundingUp(numerator1, numerator2, sqrtPriceBX96),
                sqrtPriceAX96
            );
        } else {
            amount0 =
                mulDiv(numerator1, numerator2, sqrtPriceBX96) /
                sqrtPriceAX96;
        }
    }

    /// @notice Calculates amount1 delta between two prices
    function calculateDeltaToken1(
        uint160 sqrtPriceAX96,
        uint160 sqrtPriceBX96,
        uint128 liquidity,
        bool roundUp
    ) internal pure returns (uint256 amount1) {
        if (sqrtPriceAX96 > sqrtPriceBX96)
            (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);

        if (roundUp) {
            amount1 = mulDivRoundingUp(
                liquidity,
                (sqrtPriceBX96 - sqrtPriceAX96),
                FixedPoint96.Q96
            );
        } else {
            amount1 = mulDiv(
                liquidity,
                (sqrtPriceBX96 - sqrtPriceAX96),
                FixedPoint96.Q96
            );
        }
    }

    /// @notice Calculates amount0 delta between two prices
    function calculateDeltaToken0(
        uint160 sqrtPriceAX96,
        uint160 sqrtPriceBX96,
        int128 liquidity
    ) internal pure returns (int256 amount0) {
        amount0 = liquidity < 0
            ? -int256(
                calculateDeltaToken0(
                    sqrtPriceAX96,
                    sqrtPriceBX96,
                    uint128(-liquidity),
                    false
                )
            )
            : int256(
                calculateDeltaToken0(
                    sqrtPriceAX96,
                    sqrtPriceBX96,
                    uint128(liquidity),
                    true
                )
            );
    }

    /// @notice Calculates amount1 delta between two prices
    function calculateDeltaToken1(
        uint160 sqrtPriceAX96,
        uint160 sqrtPriceBX96,
        int128 liquidity
    ) internal pure returns (int256 amount1) {
        amount1 = liquidity < 0
            ? -int256(
                calculateDeltaToken1(
                    sqrtPriceAX96,
                    sqrtPriceBX96,
                    uint128(-liquidity),
                    false
                )
            )
            : int256(
                calculateDeltaToken1(
                    sqrtPriceAX96,
                    sqrtPriceBX96,
                    uint128(liquidity),
                    true
                )
            );
    }


    function mulDivRoundingUp(uint256 a, uint256 b, uint256 denominator) internal pure returns (uint256 result) {
        result = mulDiv(a, b, denominator);
        if (mulmod(a, b, denominator) > 0) {
            require(result < type(uint256).max);
            result++;
        }
    }

    function divRoundingUp(uint256 numerator, uint256 denominator) internal pure returns (uint256 result) {
        assembly {
            result := add(div(numerator, denominator), gt(mod(numerator, denominator), 0))
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

    /**
     * @dev Returns the division of two unsigned integers, with a success flag (no division by zero).
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (uint256 result) {
        unchecked {
            if (b == 0) revert InternalMath__DivisionByZero();
            return a / b;
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an success flag (no overflow).
     */
    function trySub(uint256 a, uint256 b) internal pure returns (uint256 result) {
        unchecked {
            if (b > a) revert InternalMath__bIsGreaterThanA();
            return a - b;
        }
    }

    function mulDivision(uint256 x, uint256 y, uint256 denominator) public pure returns (uint256 result) {
        // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
        // use the Chinese Remainder Theorem to reconstruct the 512-bit result. The result is stored in two 256
        // variables such that product = prod1 * 2^256 + prod0.
        uint256 prod0; // Least significant 256 bits of the product
        uint256 prod1; // Most significant 256 bits of the product
        assembly ("memory-safe") {
            let mm := mulmod(x, y, not(0))
            prod0 := mul(x, y)
            prod1 := sub(sub(mm, prod0), lt(mm, prod0))
        }
    
        // Handle non-overflow cases, 256 by 256 division.
        if (prod1 == 0) {
            unchecked {
                return prod0 / denominator;
            }
        }
    
        // Make sure the result is less than 2^256. Also prevents denominator == 0.
        if (prod1 >= denominator) {
            revert InternalMath__MulDivOverflow(x, y, denominator);
        }
    
        ////////////////////////////////////////////////////////////////////////////
        // 512 by 256 division
        ////////////////////////////////////////////////////////////////////////////
    
        // Make division exact by subtracting the remainder from [prod1 prod0].
        uint256 remainder;
        assembly ("memory-safe") {
            // Compute remainder using the mulmod Yul instruction.
            remainder := mulmod(x, y, denominator)
    
            // Subtract 256 bit number from 512-bit number.
            prod1 := sub(prod1, gt(remainder, prod0))
            prod0 := sub(prod0, remainder)
        }
    
        unchecked {
            // Calculate the largest power of two divisor of the denominator using the unary operator ~. This operation cannot overflow
            // because the denominator cannot be zero at this point in the function execution. The result is always >= 1.
            // For more detail, see https://cs.stackexchange.com/q/138556/92363.
            uint256 lpotdod = denominator & (~denominator + 1);
            uint256 flippedLpotdod;
    
            assembly ("memory-safe") {
                // Factor powers of two out of denominator.
                denominator := div(denominator, lpotdod)
    
                // Divide [prod1 prod0] by lpotdod.
                prod0 := div(prod0, lpotdod)
    
                // Get the flipped value `2^256 / lpotdod`. If the `lpotdod` is zero, the flipped value is one.
                // `sub(0, lpotdod)` produces the two's complement version of `lpotdod`, which is equivalent to flipping all the bits.
                // However, `div` interprets this value as an unsigned value: https://ethereum.stackexchange.com/q/147168/24693
                flippedLpotdod := add(div(sub(0, lpotdod), lpotdod), 1)
            }
    
            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * flippedLpotdod;
    
            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;
    
            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also works
            // in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256
    
            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
        }
    }
}
