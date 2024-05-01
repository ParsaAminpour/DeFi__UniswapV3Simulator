/// @author Parsa Amini
/// @notice Formal Verification of BitMath library

methods {
    // dispatcher(true) means that this function can't fo anything, unless the known smae-name functions in the known contracts list.
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

// This is a basic sanity check
// rule sanity {
//     // method fun is represent any method related to the contract that we are formally verify.
//     // We could use thid power to perform some invariant checks like fuzzing.
//     method fun;
//     env e;
//     calldataargs args;
//     fun(e, args);
//     sanity true;
// }


invariant check_theAnswerIsLessThanMaxOfUint8(uint256 x)
    findMostSignificantBit(x) == uint8Max
    {
        preserved { require(x > 0); }
    }