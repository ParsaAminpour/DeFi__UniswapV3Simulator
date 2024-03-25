// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

library Position {
    struct Info {
        uint128 liquidity;
    }

    function update(Info storage self, uint128 _newLiquidity) internal {
        uint128 new_liquidity = self.liquidity + _newLiquidity;
        self.liquidity = new_liquidity;
    }

    function get(mapping(bytes32 => Position.Info) storage self, address _owner, int24 _lowerTick, int24 _upperTick)
        internal
        view
        returns (Position.Info storage position)
    {
        position = self[keccak256(abi.encodePacked(_owner, _lowerTick, _upperTick))];
    }
}
