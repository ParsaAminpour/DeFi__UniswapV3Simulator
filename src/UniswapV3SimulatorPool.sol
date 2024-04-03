// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Position} from "./libraries/Position.sol";
import {Tick} from "./libraries/Tick.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from "./libraries/SafeCast.sol";
import {TickBitmap} from "./libraries/TickBitmap.sol";
import {TickMath} from "./libraries/TickMath.sol";
import {SwapMath} from "./libraries/SwapMath.sol";
import {InternalMath} from "./libraries/InternalMath.sol";
import {LiquidityMath} from "./libraries/LiquidityMath.sol";
import {IUniswapV3MintCallback} from "./interfaces/IUniswapV3MintCallback.sol";
import {IUniswapV3SwapCallback} from "./interfaces/IUniswapV3SwapCallback.sol";
import {IUniswapV3FlashCallback} from "./interfaces/IUniswapV3FlashCallback.sol";
import {IUniswapV3PoolDeployer} from "./interfaces/IUniswapV3PoolDeployer.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/*
 * @author Parsa Amini (parsa.aminpour@gmail.com)
 * @notice this contract is loosely based on the UniswapV3 Pool implementation as it expected.
*/
contract UniswapV3SimulatorPool is ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using SafeCast for int256;
    using Tick for mapping(int24 => Tick.Info);
    using Position for mapping(bytes32 => Position.Info);
    using TickBitmap for mapping(int16 word => uint256 value);
    using Position for Position.Info;

    error UniswapV3SimulatorPool__InsufficientInputAmount();
    error UniswapV3SimulatorPool__InlvalidTokenToSwap();
    error UniswapV3SimulatorPool__InvalidTickRange();
    error UniswapV3SimulatorPool__FlashRevertedUnpaid();

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
        uint256 liquidity,
        int24 tick
    );
    event Flash(uint256 indexed amount0, uint256 indexed amount1, address owner);
    // uint256 fee0,
    // uint256 fee1,

    ////// HARD-CODED AND WILL BE REMOVED ////// @audit
    int24 public constant MIN_TICK = -887272;
    int24 public constant MAX_TICK = -MIN_TICK;
    ////////////////////////////////////////////

    // compresed slot0 data for pool managing
    struct Slot0 {
        uint160 sqrtPriceX96;
        int24 tick;
        bool unlocked;
    }

    struct SwapState {
        uint256 amountSpecifiedRemaining;
        uint256 amountCalculated;
        uint160 sqrtPriceX96;
        int24 tick;
    }

    struct stepState {
        uint160 sqrtPriceStartX96;
        uint160 sqrtPriceNextX96;
        int24 nextTick;
        uint256 amountIn;
        uint256 amountOut;
        bool initialized;
    }

    Slot0 public slot0;

    address public immutable factory;
    address public immutable token0;
    address public immutable token1;

    uint24 public immutable fee;

    int24 public immutable tickSpace;
    // uint128 public immutable maxLiquidityPerTick;

    // @audit should be uint128 BTW
    uint256 public liquidity;

    mapping(int24 tick => Tick.Info) private ticks;
    mapping(bytes32 => Position.Info) private positions;
    mapping(int16 => uint256) private tickBitmap;

    modifier lock() {
        require(slot0.unlocked, "UniswapV3SimulatorPool__ContractIsLocked");
        slot0.unlocked = false;
        _;
        slot0.unlocked = true;
    }

    constructor() {
        int24 tick_spacing;
        // In here the msg.sender is the factory contract indeed.
        (factory, token0, token1, fee, tick_spacing) = IUniswapV3PoolDeployer(msg.sender).parameters();
        tickSpace = tick_spacing;
        //@audit implementing maxLiquidity state variable.
    }

    /*
     * @param _owenr is an address to track the owner of the liquidity.
     * @param _lowerTick lower ticks to set the bounds of a price range.
     * @param _upperTick upper ticks to set the bounds of a price range.
     * @param _amount is the amount of liquidity that we want to add.
     * @param _data is the bytes format data to send via the transaction.
     * @return amount0 is the amount related to token0 that added to the pool based on the _amount.
     * @return amount1 is the amount related to token1 that added to the pool based on the _amount.
     * @dev for consider slippage protection we won't manipulate the mint-core function, slippage protection will be implemented at the Interacttor contract.
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

        // ticks.update(_lowerTick, _amount, true);
        // ticks.update(_upperTick, _amount, false);

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
        direction is the flag that controls swap direction:
        when true, token0 is traded in for token1; (SELLING ETH)
        when false, it’s the opposite. (BUYING ETH)
        For example, if token0 is ETH and token1 is USDC, setting zeroForOne to true means buying USDC for ETH. 
     * @param _amount is the amount to buy or sell based on the direction.
     * @param sqrtPriceLimitX96 is bounderies related to new price that we will estimate it during this function.
     * @param sqrtPriceLimitY96 is bounderies related to the slippage protection that user define, the default is on 0.1% but because of the volatility this could be an arbitary arg.
     * @param _data is the bytes data to pass into the transaction.
     * @return amountIn is the amount of tokenX.
     * @return amountOut is the maount of tokenY that you will receive based on the estimated next price.
    */
    function swap(address _to, bool direction, uint256 _amount, uint160 sqrtPriceLimitX96, bytes calldata _data)
        external
        nonReentrant
        lock
        returns (int256 amountIn, int256 amountOut)
    {
        // we should estimate the target price based on the amountIn
        // gas optimization
        Slot0 memory slot = slot0;

        SwapState memory state = SwapState({
            amountSpecifiedRemaining: _amount,
            amountCalculated: 0,
            sqrtPriceX96: slot.sqrtPriceX96,
            tick: slot.tick
        });

        stepState memory step;
        while (state.amountSpecifiedRemaining > 0) {
            step.sqrtPriceStartX96 = state.sqrtPriceX96;

            (step.nextTick, step.initialized) = tickBitmap.nextInitializedTickViaWord(state.tick, 1, direction);
            // The sqrtPriceNext in here is not the actual/possible amount, is based on the user's arbitary amount. we wull calculate the possible amount later.
            step.sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(step.nextTick);

            // Now we have new sqrtPrice and new tick, let's calculate the amountIn and amountOut using these results.
            // step.amountIn is the number of tokens the price range can buy from the user
            // step.amountOut  is the related number of the other token the pool can sell to the user
            // state.sqrtPriceX96 is the new current price, i.e. the price that will be set after the current swap
            (state.sqrtPriceX96, step.amountIn, step.amountOut) = SwapMath.computeSwapStep(
                step.sqrtPriceStartX96,
                (direction ? step.sqrtPriceNextX96 < sqrtPriceLimitX96 : step.sqrtPriceNextX96 > sqrtPriceLimitX96)
                    ? sqrtPriceLimitX96
                    : step.sqrtPriceNextX96,
                liquidity,
                _amount
            );

            state.amountSpecifiedRemaining -= step.amountIn;
            state.amountCalculated += step.amountOut;
            state.tick = TickMath.getTickAtSqrtRatio(state.sqrtPriceX96);
        }

        if (slot.tick != state.tick) {
            (slot0.tick, slot0.sqrtPriceX96) = (state.tick, state.sqrtPriceX96);
        }

        (amountIn, amountOut) = direction
            ? ((_amount - state.amountSpecifiedRemaining).toInt256(), -((state.amountCalculated).toInt256()))
            : (-(state.amountCalculated).toInt256(), (_amount - state.amountSpecifiedRemaining).toInt256());

        if (direction) {
            // SELLING TOKEN0 TO THE POOL AND GET CORRESPOND TOKEN (TOKEN1)
            IERC20(token1).safeTransfer(_to, uint256(-amountOut));

            uint256 balance0Before = balance0();
            IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(amountIn, -amountOut, _data);

            if (balance0Before + uint256(amountIn) > balance0()) {
                revert UniswapV3SimulatorPool__InsufficientInputAmount();
            }
        } else {
            // VICE VERSA
            IERC20(token0).safeTransfer(_to, uint256(-amountIn));

            uint256 balance1Before = balance1();
            IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(-amountIn, amountOut, _data);

            if (balance1Before + uint256(amountOut) > balance1()) {
                revert UniswapV3SimulatorPool__InsufficientInputAmount();
            }
        }

        emit Swap(msg.sender, _to, amountIn, amountOut, slot0.sqrtPriceX96, liquidity, slot0.tick);
    }

    /*
     * @notice it is possible to borrow tokens during a swap, but you had to return them or an equal amount of the other pool token, in the same transaction.
     * @param _amount0 amount related to the token0.
     * @param _amount1 amount related to the token1.
     * @param _fee0 The fee amount in token0 due to the pool by the end of the flash
     * @param _fee1 The fee amount in token1 due to the pool by the end of the flash
     * @param _data Any data passed through by the caller via the IUniswapV3PoolActions#flash call
    */
    function flash(uint256 _amount0, uint256 _amount1, /*uint256 _fee0*/ /*uint256 _fee1*/ bytes memory _data)
        external
    {
        require(_amount0 == 0 && _amount1 == 0, "UniswapV3SimulatorPool__InvalidAmounts");

        uint256 balance_before_flash0 = IERC20(token0).balanceOf(address(this));
        uint256 balance_before_flash1 = IERC20(token1).balanceOf(address(this));

        if (_amount0 > 0) IERC20(token0).safeTransfer(msg.sender, _amount0);
        if (_amount1 > 0) IERC20(token1).safeTransfer(msg.sender, _amount1);
        // tmp fee0 and fee1 amount.
        IUniswapV3FlashCallback(msg.sender).uniswapV3FlashCallback(0, 0, _data);

        if (balance_before_flash0 > IERC20(token0).balanceOf(address(this))) {
            revert UniswapV3SimulatorPool__FlashRevertedUnpaid();
        }
        if (balance_before_flash1 > IERC20(token1).balanceOf(address(this))) {
            revert UniswapV3SimulatorPool__FlashRevertedUnpaid();
        }

        emit Flash(_amount0, _amount1, msg.sender);
    }

    ////////////////////////////////////////
    ////    Internal  View Functions   /////
    ////////////////////////////////////////
    function balance0() internal view returns (uint256 balance) {
        balance = IERC20(token0).balanceOf(address(this));
    }

    function balance1() internal view returns (uint256 balance) {
        balance = IERC20(token1).balanceOf(address(this));
    }
}
