// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

library BitMath {
    /// @notice Returns the index of the most significant bit of the number,
    ///     where the least significant bit is at index 0 and the most significant bit is at index 255
    ///
    /// @dev this function actually calculate the most significant bit of the result of (mask & currentTick) array of bits.
    ///
    /// @dev The function satisfies the property:
    ///     x >= 2**mostSignificantBit(x) and x < 2**(mostSignificantBit(x)+1)
    ///
    /// @param x the value for which to compute the most significant bit, must be greater than 0
    /// @return r the index of the most significant bit
    // @audit needs Formal Verification.
    function findMostSignificantBit(uint256 x) internal pure returns (uint8 r) {
        require(x > 0);
        // represent to 2 ** 128
        if (x >= 0x100000000000000000000000000000000) {
            x >>= 128;
            r += 128;
        }
        // represent to 2 ** 64
        if (x >= 0x10000000000000000) {
            x >>= 64;
            r += 64;
        }
        // represent to 2 ** 32
        if (x >= 0x100000000) {
            x >>= 32;
            r += 32;
        }
        // represent to 2 ** 16
        if (x >= 0x10000) {
            x >>= 16;
            r += 16;
        }
        // represent to 2 ** 8
        if (x >= 0x100) {
            x >>= 8;
            r += 8;
        }
        // represent to 2 ** 4
        if (x >= 0x10) {
            x >>= 4;
            r += 4;
        }
        // represent to 2 ** 2
        if (x >= 0x4) {
            x >>= 2;
            r += 2;
        }
        if (x >= 0x2) r += 1;
    }

    /// @notice Returns the index of the least significant bit of the number,
    ///     where the least significant bit is at index 0 and the most significant bit is at index 255
    /// @dev The function satisfies the property:
    ///     (x & 2**leastSignificantBit(x)) != 0 and (x & (2**(leastSignificantBit(x)) - 1)) == 0)
    /// @param x the value for which to compute the least significant bit, must be greater than 0
    /// @return r the index of the least significant bit
    // @audit needs formal verification
    function leastSignificantBit(uint256 x) internal pure returns (uint8 r) {
        require(x > 0);

        r = 255;
        if (x & type(uint128).max > 0) {
            r -= 128;
        } else {
            x >>= 128;
        }
        if (x & type(uint64).max > 0) {
            r -= 64;
        } else {
            x >>= 64;
        }
        if (x & type(uint32).max > 0) {
            r -= 32;
        } else {
            x >>= 32;
        }
        if (x & type(uint16).max > 0) {
            r -= 16;
        } else {
            x >>= 16;
        }
        if (x & type(uint8).max > 0) {
            r -= 8;
        } else {
            x >>= 8;
        }
        if (x & 0xf > 0) {
            r -= 4;
        } else {
            x >>= 4;
        }
        if (x & 0x3 > 0) {
            r -= 2;
        } else {
            x >>= 2;
        }
        if (x & 0x1 > 0) r -= 1;
    }
}
