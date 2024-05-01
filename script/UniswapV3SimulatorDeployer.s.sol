// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {console } from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {IUniswapV3Manager} from "../src/interfaces/IUniswapV3Manager.sol";
import {FixedPoint96} from "../src/libraries/FixedPoints.sol";
import {InternalMath} from "../src/libraries/InternalMath.sol";
import {UniswapV3SimulatorPoolFactory} from "../src/UniswapV3SimulatorPoolFactory.sol";
import {UniswapV3SimulatorManager} from "../src/UniswapV3SimulatorManager.sol";
import {UniswapV3SimulatorPool} from "../src/UniswapV3SimulatorPool.sol";
import {UniswapV3SimulatorQuoter} from "../src/UniswapV3SimulatorQuoter.sol";
import { ERC20Mock } from "../test/mocks/ERC20Mock.sol";
import { PoolHandler } from "../test/PoolHandler.sol";


contract DeployDevelopment is Script, PoolHandler {
    struct TokenBalances {
        uint256 uni;
        uint256 usdc;
        uint256 usdt;
        uint256 wbtc;
        uint256 weth;
    }

    TokenBalances balances =
        TokenBalances({
            uni: 200 ether,
            usdc: 2_000_000 ether,
            usdt: 2_000_000 ether,
            wbtc: 20 ether,
            weth: 100 ether
        });

    function run() public {
        // DEPLOYING STARGED
        vm.startBroadcast();

        ERC20Mock weth = new ERC20Mock("Wrapped Ether", "WETH", 1_000 ether);
        ERC20Mock usdc = new ERC20Mock("USD Coin", "USDC", 1_000 ether);
        ERC20Mock uni = new ERC20Mock("Uniswap Coin", "UNI", 1_000 ether);
        ERC20Mock wbtc = new ERC20Mock("Wrapped Bitcoin", "WBTC", 1_000 ether);
        ERC20Mock usdt = new ERC20Mock("USD Token", "USDT", 1_000 ether);

        UniswapV3SimulatorPoolFactory factory = new UniswapV3SimulatorPoolFactory(20);
        UniswapV3SimulatorManager manager = new UniswapV3SimulatorManager(address(factory));
        UniswapV3SimulatorQuoter quoter = new UniswapV3SimulatorQuoter(address(factory));

        UniswapV3SimulatorPool wethUsdc = deployPool(
            factory,
            address(weth),
            address(usdc),
            3000,
            5000
        );

        UniswapV3SimulatorPool wethUni = deployPool(
            factory,
            address(weth),
            address(uni),
            3000,
            10
        );

        UniswapV3SimulatorPool wbtcUSDT = deployPool(
            factory,
            address(wbtc),
            address(usdt),
            3000,
            20_000
        );

        UniswapV3SimulatorPool usdtUSDC = deployPool(
            factory,
            address(usdt),
            address(usdc),
            500,
            1
        );

        uni.mint(msg.sender, balances.uni);
        usdc.mint(msg.sender, balances.usdc);
        usdt.mint(msg.sender, balances.usdt);
        wbtc.mint(msg.sender, balances.wbtc);
        weth.mint(msg.sender, balances.weth);

        uni.approve(address(manager), 100 ether);
        usdc.approve(address(manager), 1_005_000 ether);
        usdt.approve(address(manager), 1_200_000 ether);
        wbtc.approve(address(manager), 10 ether);
        weth.approve(address(manager), 11 ether);

        manager.mint(
            mintParams(
                address(weth),
                address(usdc),
                4545,
                5500,
                1 ether,
                5000 ether
            )
        );
        // manager.mint(
        //     mintParams(address(weth), address(uni), 7, 13, 10 ether, 100 ether)
        // );

        // manager.mint(
        //     mintParams(
        //         address(wbtc),
        //         address(usdt),
        //         19400,
        //         20500,
        //         10 ether,
        //         200_000 ether
        //     )
        // );
        // manager.mint(
        //     mintParams(
        //         address(usdt),
        //         address(usdc),
        //         uint160(77222060634363714391462903808), //  0.95, int(math.sqrt(0.95) * 2**96)
        //         uint160(81286379615119694729911992320), // ~1.05, int(math.sqrt(1/0.95) * 2**96)
        //         1_000_000 ether,
        //         1_000_000 ether,
        //         500
        //     )
        // );

        vm.stopBroadcast();
        // DEPLOYING DONE

        console.log("WETH address", address(weth));
        console.log("UNI address", address(uni));
        console.log("USDC address", address(usdc));
        console.log("USDT address", address(usdt));
        console.log("WBTC address", address(wbtc));

        console.log("Factory address", address(factory));
        console.log("Manager address", address(manager));
        console.log("Quoter address", address(quoter));

        console.log("USDT/USDC address", address(usdtUSDC));
        console.log("WBTC/USDT address", address(wbtcUSDT));
        console.log("WETH/UNI address", address(wethUni));
        console.log("WETH/USDC address", address(wethUsdc));
    }
}