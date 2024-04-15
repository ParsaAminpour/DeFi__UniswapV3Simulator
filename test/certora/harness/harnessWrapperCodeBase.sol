// SPDXLicense-Identifier: MIT
pragma solidity 0.8.20;

import {BitMath} from "../../../../src/libraries/BitMath.sol";

/// @author Parsa Amini
/// @notice this contract is a wrapper for all internal functions realted to
///    UniswapV3Simulator libraries to make them external in terms of using in spec formal verifications.
contract harnessWrapperCodeBase {
    function findMostSignificantBit(uint256 x) external pure returns (uint8 r) {
        return BitMath.findMostSignificantBit(x);
    }
}
