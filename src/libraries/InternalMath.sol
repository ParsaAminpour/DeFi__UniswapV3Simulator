// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { mulDiv } from "@prb-math/contracts/Common.sol";
import { FixedPoint96 } from "./FixedPoints.sol";
import { SafeCast } from "./SafeCast.sol";

library InternalMath {
    using SafeCast for uint256;

    error InternalMath__Overflow();
    error InternalMath__DivisionByZero();

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
        returns(uint160 nextPriceSqrtX96)
    {
        uint256 amount = _amount << FixedPoint96.RESOLUTION;
        uint160 delta_sqrt = tryDiv(amount, _liquidity).toUint160();
        nextPriceSqrtX96 = tryAdd(_sqrtPriceX96, delta_sqrt).toUint160();
    }


    ///////////////////////////////////
    ///   Calculation Mathematical  ///
    ///////////////////////////////////
    function calculateDeltaToken0(
        uint160 sqrtPriceAX96,
        uint160 sqrtPriceBX96,
        uint256 liquidity
    ) internal pure returns (uint256 amount0) {
        // amount0 = liquidity < 0
        //     ? -int256(
        //         calcAmount0Delta(
        //             sqrtPriceAX96,
        //             sqrtPriceBX96,
        //             uint128(-liquidity),
        //             false
        //         )
        //     )
        //     : int256(
        //         calcAmount0Delta(
        //             sqrtPriceAX96,
        //             sqrtPriceBX96,
        //             uint128(liquidity),
        //             true
        //         )
        //     );
        amount0 = 0;
    }

    /// @notice Calculates amount1 delta between two prices
    function calculateDeltaToken1(
        uint160 sqrtPriceAX96,
        uint160 sqrtPriceBX96,
        uint256 liquidity
    ) internal pure returns (uint256 amount1) {
        // amount1 = liquidity < 0
        //     ? -int256(
        //         calcAmount1Delta(
        //             sqrtPriceAX96,
        //             sqrtPriceBX96,
        //             uint128(-liquidity),
        //             false
        //         )
        //     )
        //     : int256(
        //         calcAmount1Delta(
        //             sqrtPriceAX96,
        //             sqrtPriceBX96,
        //             uint128(liquidity),
        //             true
        //         )
        //     );
        amount1 = 0;
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

    /**
     * @dev Returns the division of two unsigned integers, with a success flag (no division by zero).
    */
     function tryDiv(uint256 a, uint256 b) internal pure returns (uint256 result) {
        unchecked {
            if (b == 0) revert InternalMath__DivisionByZero();
            return a / b;
        }
    }

}
