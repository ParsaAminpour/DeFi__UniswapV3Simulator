// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { InternalMath } from "../../src/libraries/InternalMath.sol";

contract InternalMathHarness {
    function getNextSqrtPriceBasedOnInput(uint160 _currentSqrtPriceX96,uint256 _liquidity,uint256 _amountRemaining,bool direction)
    external
    pure
    returns (uint160 nextCalculatedSqrtPriceX96) {
        return InternalMath.getNextSqrtPriceBasedOnInput(
            _currentSqrtPriceX96, _liquidity, _amountRemaining, direction
        );
    }

    function mulDivRoundingUp(uint256 a, uint256 b, uint256 denominator) external pure returns(uint256 result) {
        result = InternalMath.mulDivRoundingUp(a, b, denominator);
    }

}