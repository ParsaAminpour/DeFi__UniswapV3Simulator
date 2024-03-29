// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { InternalMath } from "./InternalMath.sol";
import { SafeCast } from "./SafeCast.sol";

library Tick {
    using InternalMath for uint256;
    using SafeCast for uint256;

    struct Info {
        bool initialized;
        // total liquidity at tick
        uint128 liquidityGross;
        // amount of liquidity added or subtracted when tick is crossed
        int128 liquidityNet;
    }

    function update(
        mapping(int24 => Tick.Info) storage self,
        int24 _tickId,
        int128 _newLiquidity,
        bool upper
    ) internal returns(bool flipped) {
        Tick.Info storage info = self[_tickId];
        if (info.liquidityGross == 0) {
            // Other significant implementation
            info.initialized = true;
        }

        // when the lower (upper) tick is crossed left to right (right to left), liquidity must be added (removed)
        info.liquidityNet = upper
            ? (info.liquidityNet) - (_newLiquidity)
            : (info.liquidityNet) + (_newLiquidity);
    }

    function cross(mapping(int24 => Tick.Info) storage self, int24 tick)
        internal
        view
        returns (int128 liquidityDelta) {
        Tick.Info storage info = self[tick];
        liquidityDelta = info.liquidityNet;
    }
}
