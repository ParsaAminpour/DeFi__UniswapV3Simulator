// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IUniswapV3Pool } from "../interfaces/IUniswapV3Pool.sol";

/// @notice The data produced/returned by the renderer will have this format:
///     data:application/json;base64,BASE64_ENCODED_JSON
/// The JSON will look like this:
/// {
///   "name": "Uniswap V3 Position",
///   "description": "USDC/DAI 0.05%, Lower tick: -520, Upper text: 490",
///   "image": "BASE64_ENCODED_SVG"
/// }
/// @dev Due to string functionality, this contract is not gas-efficient.
library NFTRenderer {
    struct RenderParams {
        address owner;
        address pool;
        int24 lowerTick;
        int24 upperTick;
        uint24 fee;
    }

    /// @notice we’ll first render an SVG, then a JSON

    function render(RenderParams memory params)
        internal
        view
        returns (string memory)
    {
        IUniswapV3Pool pool = IUniswapV3Pool(params.pool);
        IERC20 token0 = IERC20(pool.token0());
        IERC20 token1 = IERC20(pool.token1());
        string memory symbol0 = token0.symbol();
        string memory symbol1 = token1.symbol();
        
        // rendering SVG template.
        string memory image = string.concat(
            "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 300 480'>",
            "<style>.tokens { font: bold 30px sans-serif; }",
            ".fee { font: normal 26px sans-serif; }",
            ".tick { font: normal 18px sans-serif; }</style>",
            renderBackground(params.owner, params.lowerTick, params.upperTick),
            renderTop(symbol0, symbol1, params.fee),
            renderBottom(params.lowerTick, params.upperTick),
            "</svg>"
        );

        string memory description = renderDescription(
            symbol0,
            symbol1,
            params.fee,
            params.lowerTick,
            params.upperTick
        );

        string memory json = string.concat(
            '{"name":"Uniswap V3 Position",',
            '"description":"',
            description,
            '",',
            '"image":"data:image/svg+xml;base64,',
            Base64.encode(bytes(image)),
            '"}'
        );

        return
            string.concat(
                "data:application/json;base64,",
                Base64.encode(bytes(json))
            );
    }

    ////////////////////////////////////////////////////////////////////////////
    //
    // INTERNAL
    //
    ////////////////////////////////////////////////////////////////////////////
    
    /// @notice The background is simply two rects.
    ///     To render them we need to find the unique hue of this token and then we concatenate all the pieces together.
    function renderBackground(
        address owner,
        int24 lowerTick,
        int24 upperTick
    ) internal pure returns (string memory background) {
        bytes32 key = keccak256(abi.encodePacked(owner, lowerTick, upperTick));
        uint256 hue = uint256(key) % 360;

        background = string.concat(
            '<rect width="300" height="480" fill="hsl(',
            Strings.toString(hue),
            ',40%,40%)"/>',
            '<rect x="30" y="30" width="240" height="420" rx="15" ry="15" fill="hsl(',
            Strings.toString(hue),
            ',100%,50%)" stroke="#000"/>'
        );
    }

    /// @notice The top template renders token symbols and pool fees
    function renderTop(
        string memory symbol0,
        string memory symbol1,
        uint24 fee
    ) internal pure returns (string memory top) {
        top = string.concat(
            '<rect x="30" y="87" width="240" height="42"/>',
            '<text x="39" y="120" class="tokens" fill="#fff">',
            symbol0,
            "/",
            symbol1,
            "</text>"
            '<rect x="30" y="132" width="240" height="30"/>',
            '<text x="39" y="120" dy="36" class="fee" fill="#fff">',
            feeToText(fee),
            "</text>"
        );
    }

    /// @notice In the bottom part, we render position tickss
    function renderBottom(int24 lowerTick, int24 upperTick)
        internal
        pure
        returns (string memory bottom)
    {
        bottom = string.concat(
            '<rect x="30" y="342" width="240" height="24"/>',
            '<text x="39" y="360" class="tick" fill="#fff">Lower tick: ',
            tickToText(lowerTick),
            "</text>",
            '<rect x="30" y="372" width="240" height="24"/>',
            '<text x="39" y="360" dy="30" class="tick" fill="#fff">Upper tick: ',
            tickToText(upperTick),
            "</text>"
        );
    }

    /// @notice A token description is a text string that contains all the same information that we render in the token’s SVG.
    function renderDescription(
        string memory symbol0,
        string memory symbol1,
        uint24 fee,
        int24 lowerTick,
        int24 upperTick
    ) internal pure returns (string memory description) {
        description = string.concat(
            symbol0,
            "/",
            symbol1,
            " ",
            feeToText(fee),
            ", Lower tick: ",
            tickToText(lowerTick),
            ", Upper text: ",
            tickToText(upperTick)
        );
    }

    /// @notice The fee is fractional and pre-defined, so we hard-code them and convert them to string.
    function feeToText(uint256 fee)
        internal
        pure
        returns (string memory feeString)
    {
        if (fee == 500) {
            feeString = "0.05%";
        } else if (fee == 3000) {
            feeString = "0.3%";
        }
    }

    /// @notice Since ticks can be positive and negative, we need to render them properly.
    function tickToText(int24 _tick)
        internal
        pure
        returns (string memory tickString)
    {
        tickString = string.concat(
            _tick < 0 ? "-" : "",
            _tick < 0
                ? Strings.toString(uint256(uint24(_tick)))
                : Strings.toString(uint256(uint24(_tick)))
        );
    }
}
