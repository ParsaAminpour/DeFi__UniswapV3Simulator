// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Position} from "./libraries/Position.sol";
import {Tick} from "./libraries/Tick.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from "./libraries/SafeCast.sol";
import {IUniswapV3MintCallback} from "./interfaces/IUniswapV3MintCallback.sol";
import { IUniswapV3SwapCallback } from "./interfaces/IUniswapV3SwapCallback.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/*
 * @author Parsa Amini
 * @notice this contract is loosely based on the UniswapV3 Pool implementation as it expected.
*/
contract UniswapV3SimulatorPool is ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using SafeCast for int256;
    using Tick for mapping(int24 => Tick.Info);
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;

    error UniswapV3SimulatorPool__InsufficientInputAmount();
    error UniswapV3SimulatorPool__InlvalidTokenToSwap();
    error UniswapV3SimulatorPool__InvalidTickRange();

    event MintSucceed(
        address indexed sender,
        address owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint256 amount0,
        uint256 amount1
    );
    event Swap(
        address indexed sender,
        address recipient,
        int256 indexed amount0,
        int256 indexed amount1,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        int24 tick
    );

    IERC20 public immutable token0;
    IERC20 public immutable token1;
    // HARD-CODED AND WILL BE REMOVED
    int24 public constant MIN_TICK = -887272;
    int24 public constant MAX_TICK = -MIN_TICK;

    // compresed slot0 data for pool managing
    struct Slot0 {
        uint160 sqrtPriceX96;
        int24 tick;
        bool unlocked;
    }

    Slot0 public slot0;

    uint128 public liquidity;

    mapping(int24 tick => Tick.Info) public ticks;
    mapping(bytes32 => Position.Info) public positions;

    modifier lock() {
        require(slot0.unlocked, "UniswapV3SimulatorPool__ContractIsLocked");
        slot0.unlocked = false;
        _;
        slot0.unlocked = true;
    }

    constructor(IERC20 _token0, IERC20 _token1, uint160 _sqrtPriceX96, int24 _tick) {
        token0 = _token0;
        token1 = _token1;
        slot0.sqrtPriceX96 = _sqrtPriceX96;
        slot0.tick = _tick;
    }

    /*
     * @param _owenr is an address to track the owner of the liquidity.
     * @param _lowerTick lower ticks to set the bounds of a price range.
     * @param _upperTick upper ticks to set the bounds of a price range.
     * @param _amount is the amount of liquidity that we want to add.
     * @param _data is the bytes format data to send via the transaction.
     * @return amount0 is the amount related to token0 that added to the pool based on the _amount.
     * @return amount1 is the amount related to token1 that added to the pool based on the _amount.
     */
    function mintLiquidity(address _owner, int24 _lowerTick, int24 _upperTick, uint128 _amount, bytes calldata _data)
        external
        nonReentrant
        lock
        returns (uint256 amount0, uint256 amount1)
    {
        if (_lowerTick < MIN_TICK || _upperTick > MAX_TICK || _lowerTick >= _upperTick) {
            revert UniswapV3SimulatorPool__InvalidTickRange();
        }

        ticks.update(_lowerTick, _amount);
        ticks.update(_upperTick, _amount);

        Position.Info storage position_info = positions.get(_owner, _lowerTick, _upperTick);
        position_info.update(_amount);

        // These values have been hard-coded and will be removed/replaced.
        amount0 = 0.99 ether;
        amount1 = 5000 ether;

        liquidity += _amount;

        uint256 balance0Before;
        uint256 balance1Before;

        if (amount0 > 0) balance0Before = balance0();
        if (amount1 > 0) balance1Before = balance1();

        // unisawpV3MintVallback is implemented on NFTManager contract indeed.
        IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(amount0, amount1, _data);

        if (amount0 == 0 && amount0 + balance0Before > balance0()) {
            revert UniswapV3SimulatorPool__InsufficientInputAmount();
        }
        if (amount1 == 0 && amount1 + balance1Before > balance1()) {
            revert UniswapV3SimulatorPool__InsufficientInputAmount();
        }

        emit MintSucceed(msg.sender, _owner, _lowerTick, _upperTick, amount0, amount1);
    }

    /*
     * @param _to is the address that we will send the amountOut of asked token.
     * @param direction is the dicrection that sepcify sell or buying tokenX, it helps us to calculate ticks.
     * @param _amount is the amount to buy or sell based on the direction.
     * @param sqrtPriceLimitX96 is bounderies related to new price that we will estimate it during this function.
     * @param _data is the bytes data to pass into the transaction.
     * @return amountIn is the amount of tokenX.
     * @return amountOut is the maount of tokenY that you will receive based on the estimated next price.
    */
    function swap(address _to, bool direction, int256 _amount, uint160 sqrtPriceLimitX96, bytes calldata _data)
        nonReentrant
        lock
        external
        returns(int256 amountIn, int256 amountOut)
    {
        // we should estimate the target price based on the amountIn

        ////////// This part hard-coded and will be removed. //////////
        int24 nextTick = 85184;
        uint160 nextSqrtPriceX96 = 5604469350942327889444743441197;

        amountIn = -0.008396714242162444 ether;
        amountOut = 42 ether;
        ///////////////////////////////////////////////////////////////
        // gas optimization
        Slot0 memory slot = slot0;

        (slot0.tick, slot0.sqrtPriceX96) = (nextTick, nextSqrtPriceX96);

        uint256 balance1Before = balance1();
        IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(
            amountIn,
            amountOut,
            _data
        );
        if (balance1Before + uint256(amountOut) < balance1())
            revert UniswapV3SimulatorPool__InsufficientInputAmount();

        // we should figure out the value of amountOut via the _amountIn and the nextPrice that we estimated.

        // Swap operation.

        emit Swap(msg.sender, _to, amountIn, amountOut, slot0.sqrtPriceX96, liquidity, slot0.tick);
    }



    function balance0() internal view returns (uint256 balance) {
        balance = token0.balanceOf(address(this));
    }

    function balance1() internal view returns (uint256 balance) {
        balance = token1.balanceOf(address(this));
    }
}
