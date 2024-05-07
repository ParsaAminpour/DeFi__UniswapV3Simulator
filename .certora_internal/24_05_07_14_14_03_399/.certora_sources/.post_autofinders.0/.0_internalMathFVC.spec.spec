/// @author Parsa Amini
/// @notice Formal Verification of InternalMath library

using InternalMathHarness as math;

methods {
    function getNextSqrtPriceBasedOnInput(uint160 _currentSqrtPriceX96,uint256 _liquidity,uint256 _amountRemaining,bool direction) external returns uint160 envfree;

    function mulDivRoundingUp(uint256 a, uint256 b, uint256 denominator) external returns uint256 envfree;
}