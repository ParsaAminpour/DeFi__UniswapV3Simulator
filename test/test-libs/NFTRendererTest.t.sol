// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { NFTRenderer as render } from "../../src/libraries/NFTRenderer.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
// import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract NFTRendererTest is Test {
    using Strings for string;

    ERC20Mock token1;
    ERC20Mock token2;
    ERC20Mock token3;
    ERC20Mock token4;

    address BOB;
    address pool;
    uint24 fee_for_test1;
    uint24 fee_for_test2;

    struct tokenInfo {
        address owner;
        string symbol1;
        string symbol2;
        uint24 fee;
        int24 lowerTick;
        int24 upperTick;
    }

    tokenInfo public info;

    function setUp() public {
        fee_for_test1 = 500;
        fee_for_test2 = 3000;

        token1 = new ERC20Mock("WETH", "WETH", 1e20);
        token2 = new ERC20Mock("USDC", "USDC", 1e20);
        token3 = new ERC20Mock("DAI", "DAI", 1e20);
        token4 = new ERC20Mock("Uniswap", "UNI", 1e20); 

        BOB = makeAddr("BOB");
        pool = makeAddr("pool");
        
        info = tokenInfo({
            owner: BOB,
            symbol1: token1.symbol(),
            symbol2: token2.symbol(),
            fee: fee_for_test1,
            lowerTick: -520,
            upperTick: 490
        });
    }

    function testTickToText() public view {
        uint16[4] memory ticks_for_test = [3245, 241, 100, 100];
        string[4] memory texts_for_test = ["3245", "241", "100", "100"];

        for (uint256 i = 0; i < ticks_for_test.length; i++) {
            string memory result = render.tickToText(int24(uint24(ticks_for_test[i])));
            assertEq(result, texts_for_test[i]);
        }

        (int24 num1, int24 num2, int24 num3, int24 num4) = (-3245, -241, -100, -100);
        (string memory str1, string memory str2, string memory str3, string memory str4) =
            ("-3245", "-241", "-100", "-100");
        
        console.log(render.tickToText(num1));
        assertEq(render.tickToText(num1), str1);
        assertEq(render.tickToText(num2), str2);
        assertEq(render.tickToText(num3), str3);
        assertEq(render.tickToText(num4), str4);
    }

    // An example: "USDC/DAI 0.05%, Lower tick: -520, Upper text: 490"
    function testDesciption() public view {
        string memory result = render.renderDescription(
            info.symbol1, info.symbol2, info.fee, info.lowerTick, info.upperTick
        );
        string memory expected_result = "WETH/USDC 0.05%, Lower tick: -520, Upper text: 490";

        assertEq(result, expected_result);
    }

    function testRender() public view {
        string memory image_encoded = Base64.encode(bytes(
            string.concat(
                "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 300 480'>",
                "<style>.tokens { font: bold 30px sans-serif; }",
                ".fee { font: normal 26px sans-serif; }",
                ".tick { font: normal 18px sans-serif; }</style>",
                render.renderBackground(info.owner, info.lowerTick, info.upperTick),
                render.renderTop(info.symbol1, info.symbol2, info.fee),
                render.renderBottom(info.lowerTick, info.upperTick),
                "</svg>"
            ))
        );

        string memory result_expected = string.concat(
            '{\n',
              '"name": ', '"Uniswap V3 Position",\n',
              '"description": ', '"WETH/USDC 0.05%, Lower tick: -520, Upper text: 490",\n',
              '"image": ', '"', image_encoded, '"\n',
            '}'
        );
        
        render.RenderParams memory render_params = render.RenderParams({
            owner: info.owner,
            pool: pool,
            lowerTick: info.lowerTick,
            upperTick: info.upperTick,
            fee: info.fee
        });

        // @audit there is a problem.
        // string memory actual_result = render.render(render_params);

        // console.log(actual_result);
    }

}