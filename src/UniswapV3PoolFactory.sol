// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {IUniswapV3PoolDeployer} from "./interfaces/IUniswapV3PoolDeployer.sol";
import {UniswapV3SimulatorPool} from "./UniswapV3SimulatorPool.sol";

/// The Factory contract is a contract that serves multiple purposes:
/// It acts as a centralized registry of Pool contracts. Using a factory, you can find all deployed pools, their tokens, and addresses.
/// It simplifies the deployment of Pool contracts. EVM allows deployment of smart contracts from smart contracts–Factory uses this feature to make pool deployment a breeze.
/// It makes pool addresses predictable and allows to compute them without making calls to the registry. This makes pools easily discoverable.
contract UniswapV3SimulatorPoolFactory is IUniswapV3PoolDeployer {
    error UniswapV3SimulatorPoolFactory__TokensAddressShouldNotBeSame();
    error UniswapV3SimulatorPoolFactory__ZeroAddressNotAllowed();
    error UniswapV3SimulatorPoolFactory__InvalidTickSpace();

    event PoolCreated(address token0, address token1, uint24 indexed tickSpacing, address pool);

    PoolParameters public params;

    mapping(uint24 tickSpacing => bool allowed) private tickSpaceAllowed;
    mapping(address token0 => mapping(address token1 => mapping(uint24 tickSpace => address pool))) private pools;

    constructor() {
        tickSpaceAllowed[10] = true;
        tickSpaceAllowed[60] = true;
    }

    function createPool(address _token0, address _token1, uint24 _tickSpacing) external returns (address pool) {
        if (_token0 == _token1) revert UniswapV3SimulatorPoolFactory__TokensAddressShouldNotBeSame();
        if (_token0 == address(0) || _token0 == address(0)) {
            revert UniswapV3SimulatorPoolFactory__ZeroAddressNotAllowed();
        }
        if (!tickSpaceAllowed[_tickSpacing]) revert UniswapV3SimulatorPoolFactory__InvalidTickSpace();

        (_token0, _token1) = _token0 > _token1 ? (_token0, _token1) : (_token1, _token0);

        params = PoolParameters({
            factory: address(this),
            token0: _token0,
            token1: _token1,
            tickSpacing: _tickSpacing,
            fee: 0 // @audit should be defined
        });

        pool = address(new UniswapV3SimulatorPool{salt: keccak256(abi.encodePacked(_token0, _token1, _tickSpacing))}());

        delete params;

        pools[_token0][_token1][_tickSpacing] = pool;
        pools[_token1][_token0][_tickSpacing] = pool;

        emit PoolCreated(_token0, _token1, _tickSpacing, pool);
    }

    function parameters()
        external
        view
        returns (address factory, address token0, address token1, uint24 fee, int24 tickSpacing)
    {}
}
