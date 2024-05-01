// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {BytesLib} from "./BytesLib.sol";

/// @author Parsa Amini
/// @dev In code, a swap path is a sequence of bytes. In Solidity, a path can be built like this:
///
/// bytes.concat(
///     bytes20(address(weth)), | -> 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
///     bytes3(uint24(60)),     | -> 00003c
///     bytes20(address(usdc)), | -> A0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
///     bytes3(uint24(10)),     | -> 00000a
///     bytes20(address(usdt)), | -> dAC17F958D2ee523a2206206994597C13D831ec7
///     bytes3(uint24(60)),     | -> 00003c
///     bytes20(address(wbtc))  | -> 2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599
/// );
library Path {
    using BytesLib for bytes;

    uint256 private constant START_INDEX = 0;

    uint256 public constant ADDRESS_LENGTH = 20;
    uint256 public constant TICK_SPACE_LENGTH = 3;

    // e.g. TokenX 60
    uint256 public constant SINGLE_TOKEN_OFFSET = ADDRESS_LENGTH + TICK_SPACE_LENGTH;
    // e.g. TokenX 60 TokenY
    uint256 public constant FULL_TOKEN_PAIR = SINGLE_TOKEN_OFFSET + ADDRESS_LENGTH;
    // e.g. TokenX 60 TokenY 10 TokenZ
    uint256 public constant MULTI_POOL_MIN_LENGTH = FULL_TOKEN_PAIR + SINGLE_TOKEN_OFFSET;

    function numPools(bytes memory path) internal pure returns (uint256 num) {
        num = (path.length - ADDRESS_LENGTH) / SINGLE_TOKEN_OFFSET;
    }

    function hasMultiplePool(bytes memory path) internal pure returns (bool has) {
        has = path.length >= MULTI_POOL_MIN_LENGTH;
    }

    /// The function simply returns the first “tokenX + tick spacing + tokenY segment encoded as bytes.
    function getFirstPoolPair(bytes memory path) internal pure returns (bytes memory first_pair) {
        first_pair = path.slice(START_INDEX, FULL_TOKEN_PAIR);
    }

    function skipToken(bytes memory path) internal pure returns (bytes memory skip) {
        require(hasMultiplePool(path), "Path__thisPathHasNotMultiplePool");
        skip = path.slice(SINGLE_TOKEN_OFFSET, path.length - SINGLE_TOKEN_OFFSET);
    }

    function decodeFirstPool(bytes memory path)
        internal
        pure
        returns (address token0, uint24 fee, address token1)
    {
        token0 = path.toAddress(START_INDEX);
        fee = path.toUint24(ADDRESS_LENGTH);
        token1 = path.toAddress(SINGLE_TOKEN_OFFSET);
    }
}
