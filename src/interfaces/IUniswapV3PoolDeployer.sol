// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title An interface for a contract that is capable of deploying Uniswap V3 Pools
/// @notice A contract that constructs a pool must implement this to pass arguments to the pool
/// @dev This is used to avoid having constructor arguments in the pool contract, which results in the init code hash
/// of the pool being constant allowing the CREATE2 address of the pool to be cheaply computed on-chain
interface IUniswapV3PoolDeployer {
    struct PoolParameters {
        address factory;
        address token0;
        address token1;
        uint24 tickSpacing;
        uint24 fee;
    }
    /// @notice Get the parameters to be used in constructing the pool, set transiently during pool creation.
    /// @dev Called by the pool constructor to fetch the parameters of the pool
    /// @return factory The factory address
    /// @return token0 The first token of the pool by address sort order
    /// @return token1 The second token of the pool by address sort order
    /// @return fee The fee collected upon every swap in the pool, denominated in hundredths of a bip
    /// @return tickSpacing The minimum number of ticks between initialized ticks

    function parameters()
        external
        view
        returns (address factory, address token0, address token1, uint24 fee, int24 tickSpacing);
}
