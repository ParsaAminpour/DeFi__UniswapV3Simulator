// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {BitMath} from "../../src/libraries/BitMath.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

// basic test
contract bitMathTest is Test {
    uint256[4] public examples;
    uint8[4] public answers;

    function setUp() public {
        examples[0] = 1;
        answers[0] = 0;

        examples[1] = 177; // 10110001 -> 177
        answers[1] = 7; // 4 + 2 + 1

        examples[2] = 13; // 00001101 -> 13
        answers[2] = 3; // 2 + 1

        examples[3] = 128; // 10000000 -> 128
        answers[3] = 7;
    }

    function test_asnwers_of_most_significant_bit_examples() public view {
        for (uint256 i = 0; i < 4; i++) {
            uint8 fetched_answer = BitMath.findMostSignificantBit(examples[i]);
            console.log(fetched_answer);

            uint8 expected_answer = answers[i];
            assertEq(fetched_answer, expected_answer);
        }
    }

    function testFailZeroNumberNoAllowed() public pure {
        BitMath.findMostSignificantBit(0);
    }
}
