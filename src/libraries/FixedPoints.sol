
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.20;

/// @title FixedPoint96
library FixedPoint96 {
    uint8 internal constant RESOLUTION = 96;
    uint256 internal constant Q96 = 0x1000000000000000000000000;
}

/// @title FixedPoint128
library FixedPoint128 {
    uint256 internal constant Q128 = 0x100000000000000000000000000000000;
}