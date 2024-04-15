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

    // mapping(uint24 tickSpacing => bool allowed) private tickSpaceAllowed;
    mapping(uint24 fee => uint24 tickSpacing) public fees;
    mapping(address token0 => mapping(address token1 => mapping(uint24 tickSpace => address pool))) private pools;

    constructor(uint24 _tickSpace) {
        // fees[_tickSpace] = true;
        // Experimental vales.
        fees[500] = 10; // 500 ~ 0.05%
        fees[3000] = 60; // 3000 ~ 0.3%
    }

    /*
     * @notice Fee amounts are hundredths of the basis point. That is, 1 fee unit is 0.0001%, 500 is 0.05%, and 3000 is 0.3%.
    */
    function createPool(address _token0, address _token1, uint24 _fee) external returns (address pool) {
        if (_token0 == _token1) revert UniswapV3SimulatorPoolFactory__TokensAddressShouldNotBeSame();
        if (_token0 == address(0) || _token0 == address(0)) {
            revert UniswapV3SimulatorPoolFactory__ZeroAddressNotAllowed();
        }
        // if (!tickSpaceAllowed[_tickSpacing]) revert UniswapV3SimulatorPoolFactory__InvalidTickSpace();

        (_token0, _token1) = _token0 > _token1 ? (_token0, _token1) : (_token1, _token0);

        uint24 _tickSpacing = fees[_fee];

        params = PoolParameters({
            factory: address(this),
            token0: _token0,
            token1: _token1,
            tickSpacing: fees[_fee],
            fee: _fee
        });

        pool = address(new UniswapV3SimulatorPool{salt: keccak256(abi.encode(_token0, _token1, _tickSpacing))}());

        delete params;

        pools[_token0][_token1][_tickSpacing] = pool;
        pools[_token1][_token0][_tickSpacing] = pool;

        emit PoolCreated(_token0, _token1, _tickSpacing, pool);
    }

    function parameters()
        external
        view
        returns (address factory, address token0, address token1, uint24 fee, uint24 tickSpacing)
    {}
}
