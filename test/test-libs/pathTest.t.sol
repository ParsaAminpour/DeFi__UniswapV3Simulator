// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {console} from "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";
import {Path} from "../../src/libraries/Path.sol";

contract pathTest is Test {
    address public weth;
    address public usdt;
    address public usdc;
    address public wbtc;

    uint24 public constant tickSpace1 = 60;
    uint24 public constant tickSpace2 = 10;

    bytes public singlePool;
    bytes public twoPools;
    bytes public threePools;

    function setUp() public {
        weth = makeAddr("weth");
        usdt = makeAddr("usdt");
        usdc = makeAddr("usdc");
        wbtc = makeAddr("wbtc");

        singlePool = bytes.concat(bytes20(weth), bytes3(tickSpace1), bytes20(usdt));

        twoPools = bytes.concat(bytes20(weth), bytes3(tickSpace1), bytes20(usdt), bytes3(tickSpace2), bytes20(wbtc));

        threePools = bytes.concat(
            bytes20(weth),
            bytes3(tickSpace1),
            bytes20(usdt),
            bytes3(tickSpace2),
            bytes20(wbtc),
            bytes3(tickSpace1),
            bytes20(usdc)
        );
    }

    function testNumPools() public {
        uint256 numForSinglePool = Path.numPools(singlePool);
        assertEq(numForSinglePool, 1);

        uint256 numForTwoPools = Path.numPools(twoPools);
        assertEq(numForTwoPools, 2);

        uint256 numForThreePools = Path.numPools(threePools);
        assertEq(numForThreePools, 3);
    }

    function testHasMultiplePool() public {
        assertFalse(Path.hasMultiplePool(singlePool));
        assertTrue(Path.hasMultiplePool(twoPools));
        assertTrue(Path.hasMultiplePool(threePools));
    }

    function testGetFirstPoolPair() public {
        bytes memory firstPoolExpected = bytes.concat(bytes20(weth), bytes3(tickSpace1), bytes20(usdt));

        bytes memory result = Path.getFirstPoolPair(twoPools);
        assertEq(firstPoolExpected, result);
    }

    function testSkipToken() public {
        bytes memory three_pools_pair_expected_after_skipping1 =
            bytes.concat(bytes20(usdt), bytes3(tickSpace2), bytes20(wbtc), bytes3(tickSpace1), bytes20(usdc));
        bytes memory result1 = Path.skipToken(threePools);
        assertEq(three_pools_pair_expected_after_skipping1, result1);

        bytes memory three_pools_pair_expected_after_skipping2 =
            bytes.concat(bytes20(wbtc), bytes3(tickSpace1), bytes20(usdc));
        bytes memory result2 = Path.skipToken(result1);
        assertEq(three_pools_pair_expected_after_skipping2, result2);
    }

    function testFailSkipToken() public {
        Path.skipToken(singlePool);
    }

    function testDecodeFirstPool() public {
        (address token0Result, uint24 tickSpaceResult, address token1Result) = Path.decodeFirstPool(threePools);
        assertEq(token0Result, weth);
        assertEq(tickSpaceResult, tickSpace1);
        assertEq(token1Result, usdt);
    }
}
