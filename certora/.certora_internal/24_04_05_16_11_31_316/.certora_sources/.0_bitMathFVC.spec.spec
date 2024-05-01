/// @author Parsa Amini
/// @notice Formal Verification of BitMath library

methods {
    function findMostSignificantBit(uint256 x) external returns uint8 envfree;
}

// work as constant variable
definition WAD() returns uint256 = 1000000000000000000;
definition uint8Max() returns uint8 = 255;


rule check_testMostSignificantBit(uint256 x) {
    require(x > 0);
    uint8 result = findMostSignificantBit(x);
    mathint expected = findMostSignificantBit(x);

    assert(result == expected);
}


invariant check_theAnswerIsLessThanMaxOfUint8(uint256 x)
    findMostSignificantBit(x) == uint8Max
    {
        preserved { require(x > 0); }
    }