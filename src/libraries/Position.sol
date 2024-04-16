// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { mulDiv } from "./InternalMath.sol";
import { FixedPoint96, FixedPoint128 } from "./FixedPoints.sol";
import { LiquidityMath } from "./LiquidityMath.sol";

library Position {
    struct Info {
        uint128 liquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
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

    function update(
        Info storage self,
        int128 liquidityDelta,
        uint256 feeGrowthInside0X128,
        uint256 feeGrowthInside1X128
    ) internal {
        uint128 tokensOwed0 = uint128(
            mulDiv(
                feeGrowthInside0X128 - self.feeGrowthInside0LastX128,
                self.liquidity,
                FixedPoint128.Q128
            )
        );
        uint128 tokensOwed1 = uint128(
            mulDiv(
                feeGrowthInside1X128 - self.feeGrowthInside1LastX128,
                self.liquidity,
                FixedPoint128.Q128
            )
        );

        self.liquidity = LiquidityMath.addLiquidity(
            self.liquidity,
            liquidityDelta
        );
        self.feeGrowthInside0LastX128 = feeGrowthInside0X128;
        self.feeGrowthInside1LastX128 = feeGrowthInside1X128;

        if (tokensOwed0 > 0 || tokensOwed1 > 0) {
            self.tokensOwed0 += tokensOwed0;
            self.tokensOwed1 += tokensOwed1;
        }
    }
}
