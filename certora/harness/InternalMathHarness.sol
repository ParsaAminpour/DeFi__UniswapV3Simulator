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
}