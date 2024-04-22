// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { mulDiv } from "./InternalMath.sol";
import { FixedPoint96, FixedPoint128 } from "./FixedPoints.sol";
import { LiquidityMath } from "./LiquidityMath.sol";

library Position {
    struct Info {
        // Liquidity amount belongs to this position.
        uint128 liquidity;
        // fee growth per unit of liquidity based on latest fee update
        uint256 feeGrowthInside0LastX128;
        // fee growth per unit of liquidity based on latest fee update
        uint256 feeGrowthInside1LastX128;
        // the fees owed to the position owner in token0/token1
        uint128 tokensOwed0; // used in collect function
        // the fees owed to the position owner in token0/token1
        uint128 tokensOwed1; // used in collect function
    }

    /// @notice This function returns position details related to the _owner and his tick boundries. 
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
