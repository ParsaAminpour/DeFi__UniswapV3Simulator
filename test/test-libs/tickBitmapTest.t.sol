// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test } from "forge-std/Test.sol";
import {TickBitmap} from "../../src/libraries/TickBitmap.sol";

contract tickBitmapTest is Test {
    using TickBitmap for mapping(int16 word => uint256 value);

    mapping(int16 word => uint256 value) public Bitmap;
    int24[9] public tickToInitialize;
    
    int24[7] public ticksToEnsure;
    int24[7] public nextTicksAnswer;

    function setUp() public {
        tickToInitialize = [-200, -55, -4, 70, 78, 84, 139, 240, 535];
    }

    function initialize_ticks() internal {
        for (uint i = 0; i < 9; i++) {
            Bitmap.flipTick(tickToInitialize[i], 1);
        }
    }

    function testGetPosition() public pure {
        int24 tickExample = 85176;
        int16 wordPosExpected = 332;
        uint8 bitPosExpected = 184;

        (int16 wordPosResult, uint8 bitPosResult) = TickBitmap.getPosition(tickExample);
        assertEq(wordPosExpected, wordPosResult);
        assertEq(bitPosExpected, bitPosResult);
    }

    function testFlipTick() public {
        int24 default_space = 1;
        int24 tick_to_examine = -230;
        Bitmap.flipTick(tick_to_examine, default_space);

        assertTrue(Bitmap.isInitialized(-230));
        assertFalse(Bitmap.isInitialized(-229));
        assertFalse(Bitmap.isInitialized(-231));
        assertFalse(Bitmap.isInitialized(-230 - 256));
        assertFalse(Bitmap.isInitialized(-230 + 256));

        // flip that identical tick again.
        Bitmap.flipTick(tick_to_examine, default_space);
        assertFalse(Bitmap.isInitialized(-230));
        assertFalse(Bitmap.isInitialized(-229));
        assertFalse(Bitmap.isInitialized(-231));
        assertFalse(Bitmap.isInitialized(-230 - 256));
        assertFalse(Bitmap.isInitialized(-230 + 256));

    }

    // When Selling tokenY (test in different critic situations)
    function testNextInitializedTickViaWordWhenDirectionIsTrue() public {
        bool direction = true;
        int24 defualt_space = 1;
        initialize_ticks();

        (int24 nextTick1, bool initialized1) = Bitmap.nextInitializedTickViaWord(
            78, defualt_space, direction);
        assertEq(nextTick1, 78);
        assertTrue(initialized1);

        (int24 nextTick2, bool initialized2) = Bitmap.nextInitializedTickViaWord(
            79, defualt_space, direction);
        assertEq(nextTick2, 78);
        assertTrue(initialized2);

        (int24 nextTick3, bool initialized3) = Bitmap.nextInitializedTickViaWord(
            258, defualt_space, direction);
        assertEq(nextTick3, 256);
        assertFalse(initialized3);

        (int24 nextTick4, bool initialized4) = Bitmap.nextInitializedTickViaWord(
            256, defualt_space, direction);
        assertEq(nextTick4, 256);
        assertFalse(initialized4);

        (int24 nextTick5, bool initialized5) = Bitmap.nextInitializedTickViaWord(
            72, defualt_space, direction);
        assertEq(nextTick5, 70);
        assertTrue(initialized5);   
    }

    // When Selling tokenX (test in different critic situations)
    function testNextInitializedTickViaWordWhenDirectionIsFalse() public {
        bool direction = false;
        int24 defualt_space = 1;
        initialize_ticks();

        (int24 nextTick1, bool initialized1) = Bitmap.nextInitializedTickViaWord(
            78, defualt_space, direction);
        assertEq(nextTick1, 84);
        assertTrue(initialized1);

        (int24 nextTick2, bool initialized2) = Bitmap.nextInitializedTickViaWord(
            -55, defualt_space, direction);
        assertEq(nextTick2, -4);
        assertTrue(initialized2);

        (int24 nextTick3, bool initialized3) = Bitmap.nextInitializedTickViaWord(
            77, defualt_space, direction);
        assertEq(nextTick3, 78);
        assertTrue(initialized3);

        (int24 nextTick4, bool initialized4) = Bitmap.nextInitializedTickViaWord(
            -56, defualt_space, direction);
        assertEq(nextTick4, -55);
        assertTrue(initialized4);

        (int24 nextTick5, bool initialized5) = Bitmap.nextInitializedTickViaWord(
            255, defualt_space, direction);
        assertEq(nextTick5, 511);
        assertFalse(initialized5);
    }
}