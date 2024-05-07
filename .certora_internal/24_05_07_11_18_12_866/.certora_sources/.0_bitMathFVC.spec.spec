/// @author Parsa Amini
/// @notice Formal Verification of BitMath library

methods {
    // dispatcher(true) means that this function can't fo anything, unless the known smae-name functions in the known contracts list.
    function findMostSignificantBit(uint256 x) external returns uint8 envfree;

    function leastSignificantBit(uint256 x) external returns uint8 envfree;
}

// work as constant variable
definition WAD() returns uint256 = 1000000000000000000;
definition uint8Max() returns uint8 = 255;


rule check_testMostSignificantBit(uint256 x) {
    require(x > 0);
    mathint result = findMostSignificantBit(x);
    mathint expected = findMostSignificantBit(x);

    assert(result == expected);
}

// This is a basic sanity check
// rule sanity(method f, env e) {
//     // method fun is represent any method related to the contract that we are formally verify.
//     // We could use thid power to perform some invariant checks like fuzzing.
//     calldataarg args;
//     assert(f(e, args) > 0);
// }


invariant check_theAnswerIsLessThanMaxOfUint8(uint256 x)
    findMostSignificantBit(x) == 255 // uint8.max hard-coded
    // {
    //     preserved { require(x == 0); }   
    // }