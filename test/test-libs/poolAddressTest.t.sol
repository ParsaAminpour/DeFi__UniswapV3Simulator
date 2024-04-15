// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {PoolAddress} from "../../src/libraries/PoolAddress.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {UniswapV3SimulatorPoolFactory} from "../../src/UniswapV3SimulatorPoolFactory.sol";
import {UniswapV3SimulatorPool} from "../../src/UniswapV3SimulatorPool.sol";

// Testing the library workflow safety using a pre-verified contract.
contract poolAddressTest is Test {
    address public token0;
    address public token1;
    uint24 public tickSpaceSample;

    UniswapV3SimulatorPoolFactory public factory_contract;

    function setUp() public {
        factory_contract = new UniswapV3SimulatorPoolFactory(20);
        token0 = makeAddr("token0");
        token1 = makeAddr("token1");
        tickSpaceSample = 20;
    }

    struct PoolParameters {
        address factory;
        address token0;
        address token1;
        uint24 tickSpacing;
        uint24 fee;
    }

    function testComputeAddress() public {
        address pool_address_created_by_factory = factory_contract.createPool(token0, token1, tickSpaceSample);

        // @audit The pool contract returned is not correct in way of computeable address.
        address self_computed_pool_address =
            PoolAddress.computeAddress(address(factory_contract), token0, token1, tickSpaceSample);

        bytes32 salt = keccak256(abi.encodePacked(token0, token1, tickSpaceSample));
        bytes32 bytescodehash = keccak256(type(UniswapV3SimulatorPool).creationCode);
        address computed_by_create2 = Create2.computeAddress(salt, bytescodehash, address(factory_contract));

        assertEq(self_computed_pool_address, computed_by_create2);

        console.log(pool_address_created_by_factory);
        console.log(self_computed_pool_address);
        console.log(computed_by_create2);
    }

    function testFailComputeAddressNotOrderedTokens() public view {
        address _token0 = address(0);
        address _token1 = address(1);

        PoolAddress.computeAddress(address(factory_contract), _token1, _token0, tickSpaceSample);
    }
}
