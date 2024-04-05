// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {BitMath} from "./BitMath.sol";

library TickBitmap {
    /*
     * @returns bitPosition is the current initialized bit related to the tick.
    */
    function getPosition(int24 tick) internal pure returns (int16 wordPosition, uint8 bitPosition) {
        wordPosition = int16(tick >> 8);
        bitPosition = uint8(int8(int16(tick % 256)));
    }

    /*
     * @notice When adding liquidity into a pool, we need to set a couple of tick flags in the bitmap:
        one for the lower tick and one for the upper tick. We do this in the flipTick method of the bitmap mapping
     * @param self is tickBitmap mapping to make this function to a method.
     * @param tick is lower or upper tick to flip the tick.
     * @param tickSpacing define only ticks divisible by the tickSpacing can be flipped. 
    */
    function flipTick(mapping(int16 => uint256) storage self, int24 tick, int24 tickSpace) internal {
        require(tick % tickSpace == 0, "TickBitmap__InvalidTickSpace");
        (int16 word, uint8 bit) = getPosition(tick / tickSpace);
        uint256 mask = 1 << bit;
        self[word] ^= mask;
    }


    function isInitialized(mapping(int16 word => uint256 value) storage self, int24 tick) internal view returns(bool initialized) {
        (int16 word, uint8 bit) = getPosition(tick);
        uint256 mask = 1 << bit;
        uint256 masked = self[word] & mask;

        initialized = masked != 0 ? true : false;
    }

    /*
     * @notice two scenraio in this function will be implemented
        1. When selling token x (ETH in our case), find the next initialized tick in the current tick’s word and to the right of the current tick.
        2. When selling token y (USDC in our case), find the next initialized tick in the next (current + 1) tick’s word and to the left of the current tick.
     * @notice Uniswap V3 uses this technique to store the information about initialized ticks, that is ticks with some liquidity.
        When a flag is set (1), the tick has liquidity; when a flag is not set (0), the tick is not initialized.
     * @param self make this function as a method of mapping(int16 => uint256).
     * @dev the rule of mask obvs is to appear the not-initialized bits in the bitMap[word] array-like bits.

     * @param tick is the current tick.
     * @param tickSpacing is always 1 until we start using it in Milestone 4.
     * @param lte is the flag that sets the direction. When true, we’re selling token x and searching for the next initialized tick to the right of the current one. When false, it’s the other way around. lte equals the swap direction: true when selling token x, false otherwise.
     * @returns nextTick which is the next tick contains liquidity.
     * @returns initialized Knowing if the next tick is initialized or not will help us save some gas in situations when there’s no initialized tick in the current word in the ticks bitmap.
    */
    function nextInitializedTickViaWord(
        mapping(int16 => uint256) storage self,
        int24 tick,
        int24 tickSpace,
        bool direction
    ) internal view returns (int24 nextTick, bool initialized) {
    
        int24 compressed = tick / tickSpace;
        if (tick < 0 && tick % tickSpace != 0) compressed--;
        // bit is related to current initialized bit position.
    
        // When we want to sell token X and searching for the next tick to the right.
        if (direction) {
            (int16 word, uint8 bit) = getPosition(compressed);
            uint256 mask = (1 << (bit + 1)) - 1; // 0000000011111111
            uint256 masked = self[word] & mask;

            // if there are no initialized ticks to the right of or at the current tick, return right mostSignificantBit in the word
            initialized = masked != 0;
            nextTick = initialized
                ? (compressed - int24(uint24(bit - BitMath.findMostSignificantBit(masked)))) * tickSpace
                : (compressed - int24(uint24(bit))) * tickSpace;
        } else {
            (int16 word, uint8 bit) = getPosition(compressed+1);
            // When we want to buy token X and searching for the next tick to the left.
            uint256 mask = ~((1 << bit) - 1); // 1111111100000000
            uint256 masked = self[word] & mask;

            // if there are no initialized ticks to the left of the current tick, return left mostSignificantBit in the word
            initialized = masked != 0;
            nextTick = initialized
                ? ((compressed + 1) + int24(uint24(BitMath.leastSignificantBit(masked) - bit))) * tickSpace
                : ((compressed + 1) + int24(uint24(type(uint8).max - bit))) * tickSpace;
        }
    }
}
