// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

library Tick {
    struct Info {
        bool initialized;
        uint128 liquidity;
    }

    function update(mapping(int24 => Tick.Info) storage self, int24 _tickId, uint128 _newLiquidity) internal {
        Tick.Info storage info = self[_tickId];
        if (info.liquidity == 0) info.initialized = true;

        uint128 newLiquidity = info.liquidity + _newLiquidity;

        info.liquidity = newLiquidity;
    }
}
