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
import { Oracle } from "./libraries/Oracle.sol";
import {FixedPoint96, FixedPoint128} from "./libraries/FixedPoints.sol";
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
    using Oracle for Oracle.Observation[65535];

    error UniswapV3SimulatorPool__FeeAccumulatedRelatedToThisPositionIsEmpty();
    error UniswapV3SimulatorPool__InsufficientInputAmount();
    error UniswapV3SimulatorPool__InlvalidTokenToSwap();
    error UniswapV3SimulatorPool__InvalidTickRange();
    error UniswapV3SimulatorPool__FlashRevertedUnpaid();
    error UniswapV3SimulatorPool__InvalidPriceSlippage();
    error UniswapV3SimulatorPool__InsufficientLiquidity(uint128 liquidity);
    error UniswapV3SimulatorPool__InvalidAddress();
    error UniswapV3SimulatorPool__AlreadyInitialized();
    error UniswapV3SimulatorPool__ZeroAmountIsNotPermitted(); 

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

    event BurnSucceed(
        address caller,
        int24 indexed lowerTick,
        int24 indexed upperTick,
        uint128 indexed liquidityAmount,
        uint256 amount0Sent,
        uint256 amount1Sent
    );

    event Collected(
        address destination,
        int24 lowerTick,
        int24 upperTick,
        uint128 indexed amount0,
        uint128 indexed amount1
    );

    event Flash(
        uint256 indexed amount0,
        uint256 indexed amount1,
        address owner
    );

    event Initialized(
        uint160 indexed price_initialized,
        int24 indexed tick_initialized
    );

    /// @dev compresed slot0 data for pool managing
    /// @dev Observations could be expand when a new observation is saved and
    ///     (nextObservationCardinality > observationCardinality) which signals that
    ///     cardinality can be expanded. If not, the oldest observation get overwritten.
    struct Slot0 {
        // currenct square root of price
        uint160 sqrtPriceX96;
        // current tick
        int24 tick;
        // Puaseable design pattern
        bool unlocked;
        // tracks the most recent observation index
        uint16 observationIndex;
        // Maximum number of observations
        // tracks the number of activated observations
        // not all observations are activated by default!
        uint16 observationCardinality;
        // Next maximum number of observations
        // tracks the next cardinality the array of observations can expand to
        uint16 nextObservationCardinality;
    }
    
    /// @dev swap state maintain the current swap state.
    /// @dev the top level state of the swap, the results of which are recorded in storage at the end.
    struct SwapState {
        // tracks the remaining amount of tokens that need to be bought by the pool.
        uint256 amountSpecifiedRemaining;
        // is the out amount calculated by the contract
        uint256 amountCalculated;
        // new current price after the swap is done.
        uint160 sqrtPriceX96;
        // new tick after the swap is done.
        int24 tick;
        // the global fee amount belongs the input token,
        uint256 feeGrowthGlobalX128;
        // The current liquidity.
        uint128 liquidity;
    }

    /// @dev step state maintain the current swap step's state.
    ///     This structure tracks the state of one iteration of an “order filling”. 
    struct stepState {
        // tracks the price the iteration begins with.
        uint160 sqrtPriceStartX96;
        // sqrtPriceNextX96 is the price at the next tick.
        uint160 sqrtPriceNextX96;
        // the next initialized tick that will provide liquidity for the swap
        int24 nextTick;
        // The amount that could be provided by liquidity (current iteration).
        uint256 amountIn;
        // The amount that could be provided by liquidity (current iteration).
        uint256 amountOut;
        // The next tick is initialized or not.
        bool initialized;
        // Amount of fee that should be paid.
        uint256 feeAmount;
    }

    struct ModifyPositionParams {
        // The owner of the position
        address owner;
        // lower tick of the position
        int24 lowerTick;
        // upper tick of the position
        int24 upperTick;
        // liquidity amount for change
        int128 liquidityDelta;
    }

    Slot0 public slot0;

    // a pool by default can store only 1 observation, which gets overwritten each time a new price is recorded
    Oracle.Observation[65535] public observations;

    address public immutable factory;
    address public immutable token0;
    address public immutable token1;

    uint24 public immutable fee;
    uint256 public feeGrowthGlobal0x128; // tracks fees accumulated in token0.
    uint256 public feeGrowthGlobal1x128; // tracks fees accumulated in token1.

    uint24 public immutable tickSpace;
    // uint128 public immutable maxLiquidityPerTick;

    // @audit should be uint128 BTW
    uint128 public liquidity;

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
        uint24 tick_spacing;
        // In here the msg.sender is the factory contract indeed.
        (factory, token0, token1, fee, tick_spacing) = IUniswapV3PoolDeployer(msg.sender).parameters();
        tickSpace = tick_spacing;
        //@audit implementing maxLiquidity state variable.
    }


    /// @notice the pool_initialize is for setting up the init price for the pool.
    /// @param _initSqrtPrice is the initial price for the token0/token1 pair.
    function pool_initialize(uint160 _initSqrtPrice) public {
        if(slot0.sqrtPriceX96 != 0) revert UniswapV3SimulatorPool__AlreadyInitialized();
        int24 init_tick = TickMath.getTickAtSqrtRatio(_initSqrtPrice);

        (uint16 init_cardinality, uint16 init_cardinality_next) = observations.initialize(_timeStamp());
        
        slot0 = Slot0({
            sqrtPriceX96: _initSqrtPrice,
            tick: init_tick,
            unlocked: true,
            observationIndex: 0,
            observationCardinality: init_cardinality,
            nextObservationCardinality: init_cardinality_next
        });

        emit Initialized(_initSqrtPrice, init_tick);
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
    function mint(address _owner, int24 _lowerTick, int24 _upperTick, uint128 _amount, bytes calldata _data)
        external
        nonReentrant
        lock
        returns (uint256 amount0, uint256 amount1)
    {
        if (_lowerTick < TickMath.MIN_TICK || _upperTick > TickMath.MAX_TICK || _lowerTick >= _upperTick) {
            revert UniswapV3SimulatorPool__InvalidTickRange();
        }
        if (_amount == 0) revert UniswapV3SimulatorPool__ZeroAmountIsNotPermitted();

        (, int256 amount0Int, int256 amount1Int) = _modifyPosition(
            ModifyPositionParams({
                owner: _owner,
                lowerTick: _lowerTick,
                upperTick: _upperTick,
                liquidityDelta: int128(_amount)
            })
        );
        
        amount0 = uint256(amount0Int);
        amount1 = uint256(amount1Int);

        uint256 balance0Before;
        uint256 balance1Before;

        if (amount0 > 0) balance0Before = balance0();
        if (amount1 > 0) balance1Before = balance1();

        // unisawpV3MintVallback is implemented on NFTManager contract indeed.
        IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(amount0, amount1, _data);

        if (amount0 > 0 && amount0 + balance0Before > balance0()) {
            revert UniswapV3SimulatorPool__InsufficientInputAmount();
        }
        if (amount1 > 0 && amount1 + balance1Before > balance1()) {
            revert UniswapV3SimulatorPool__InsufficientInputAmount();
        }

        emit MintSucceed(msg.sender, _owner, _lowerTick, _upperTick, amount0, amount1);
    }


    /// @param _lowerTick The lower tick of the position for which to burn liquidity
    /// @param _upperTick The upper tick of the position for which to burn liquidity
    /// @param _amount How much liquidity to burn
    /// @return amount0 The amount of token0 sent to the recipient
    /// @return amount1 The amount of token1 sent to the recipient
    /// @dev sending the porition of accumulated fees will accomplish in a seperated function called collect().
    /// @notice During burning, the position will be updated and the token amounts it owes will be updated as well.
    function burn(int24 _lowerTick, int24 _upperTick, uint128 _amount)
        external
        lock()
        returns(uint256 amount0, uint256 amount1)
    {
        // amount0Int and amount1Int are the amount of token0 and token1 owed to the pool,
        //     negative if the pool should pay the recipient, like this situation.
        (Position.Info storage info, int256 amount0Int, int256 amount1Int) = 
            _modifyPosition(
                ModifyPositionParams({
                    owner: msg.sender,
                    lowerTick: _lowerTick,
                    upperTick: _upperTick,
                    liquidityDelta: -int128(_amount)
                })
            );
            
        // amount0Int and amount1Int are both negative brcause the liquidityDelta is negative
        amount0 = uint256(-amount0Int);
        amount1 = uint256(-amount1Int);
        
        if (amount0 > 0 || amount1 > 0) {
            // adding the fees owed to the position.
            info.tokensOwed0 += amount0.toUint128();
            info.tokensOwed1 += amount1.toUint128();
        }
        
        emit BurnSucceed(msg.sender, _lowerTick, _upperTick, _amount, amount0, amount1);
    }
    
    /// @notice this function is used for collecting the accumulated fees from a specific position.
    /// @dev One of the amount requested might be zero, so for gathering whole fees we could pass the
    ///     amount that is greater than the actual token owed amount or type(uint128).max.
    /// @param _to is the address that will recieve the fees collected.
    /// 
    function collect(
        address _to,
        int24 _lowerTick,
        int24 _upperTick,
        uint128 _amount0Requested,
        uint128 _amount1Requested
    ) external lock nonReentrant returns (uint128 amount0, uint128 amount1) {
        if (_to == address(0)) revert UniswapV3SimulatorPool__InvalidAddress();
        if (_lowerTick > _upperTick) revert UniswapV3SimulatorPool__InvalidTickRange();

        Position.Info storage info = positions.get(msg.sender, _lowerTick, _upperTick);
        Position.Info memory tmp_info = info;

        if(tmp_info.tokensOwed0 == 0 && tmp_info.tokensOwed1 == 0) revert UniswapV3SimulatorPool__FeeAccumulatedRelatedToThisPositionIsEmpty();

        amount0 = (_amount0Requested > tmp_info.tokensOwed0 || _amount0Requested == type(uint128).max)
            ? tmp_info.tokensOwed0 : _amount0Requested;
        
        amount1 = (_amount1Requested > tmp_info.tokensOwed1 || _amount1Requested == type(uint128).max)
            ? tmp_info.tokensOwed0 : _amount1Requested;
            
        // follows CEI
        if (amount0 > 0) {
            info.tokensOwed0 -= amount0;
            IERC20(token0).safeTransfer(_to, amount0);
        }
        if (amount1 > 0) {
            info.tokensOwed1 -= amount1;
            IERC20(token1).safeTransfer(_to, amount1);
        }

        emit Collected(_to, _lowerTick, _upperTick, amount0, amount1);
    }  


    /*
     * @param _to is the address that we will send the amountOut of asked token.
     * @param direction is the dicrection that sepcify sell or buying tokenX, it helps us to calculate ticks.
        direction is the flag that controls swap direction:
        when true, token0 is traded in for token1; (i.e. SELLING ETH)
        when false, it’s the opposite. (i.e. BUYING ETH)
        For example, if token0 is ETH and token1 is USDC, setting zeroForOne to true means buying USDC for ETH (selling ETH indeed). 
     * @param _amount is the amount to buy or sell based on the direction.
     * @param sqrtPriceLimitX96 is bounderies related to new price that we will estimate it during this function.
     * @param sqrtPriceLimitY96 is bounderies related to the slippage protection that user define, the default is on 0.1% but because of the volatility this could be an arbitary arg.
     * @param _data is the bytes data to pass into the transaction.
     * @return amountIn is the amount of tokenX.
     * @return amountOut is the maount of tokenY that you will receive based on the estimated next price.
     * @dev during a swap, fees are collected in either token0 or token1, not both of them!
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
        uint128 _liq = liquidity;

        // slippage bounderies check
        if(direction
            ? sqrtPriceLimitX96 > slot.sqrtPriceX96 || sqrtPriceLimitX96 < TickMath.MIN_SQRT_RATIO
            : sqrtPriceLimitX96 < slot.sqrtPriceX96 || sqrtPriceLimitX96 > TickMath.MAX_SQRT_RATIO
        ) revert UniswapV3SimulatorPool__InvalidPriceSlippage();


        SwapState memory state = SwapState({
            amountSpecifiedRemaining: _amount,
            amountCalculated: 0,
            sqrtPriceX96: slot.sqrtPriceX96,
            tick: slot.tick,
            feeGrowthGlobalX128: direction
                ? feeGrowthGlobal0x128
                : feeGrowthGlobal1x128,
            liquidity: _liq
        });

        // we will loop until the state.amountSpecifiedRemaining become fulfulled.
        // The state.amountSpecifiedRemaining 0 means that the pool has enough liquidity to provide a swap for _amount.
        // In the loop, we set up a price range that should provide liquidity for the swap. The range is from state.sqrtPriceX96 to step.sqrtPriceNextX96,
        //     where the latter is the price at the next initialized tick.
        while (state.amountSpecifiedRemaining > 0 && state.sqrtPriceX96 != sqrtPriceLimitX96) {
            stepState memory step;
            step.sqrtPriceStartX96 = state.sqrtPriceX96;

            (step.nextTick, step.initialized) = tickBitmap.nextInitializedTickViaWord(state.tick, int24(tickSpace), direction);
            // The sqrtPriceNext in here is not the actual/possible amount, is based on the user's arbitary amount. we will calculate the possible amount later.
            step.sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(step.nextTick);

            // Now we have new sqrtPrice and new tick, let's calculate the amountIn and amountOut using these results.
            // step.amountIn is the number of tokens the price range can buy from the user
            // step.amountOut  is the related number of the other token the pool can sell to the user
            // state.sqrtPriceX96 is the new current price, i.e. the price that will be set after the current swap
            (state.sqrtPriceX96, step.amountIn, step.amountOut, step.feeAmount) = SwapMath.computeSwapStep(
                step.sqrtPriceStartX96,
                (direction ? step.sqrtPriceNextX96 < sqrtPriceLimitX96 : step.sqrtPriceNextX96 > sqrtPriceLimitX96)
                    ? sqrtPriceLimitX96
                    : step.sqrtPriceNextX96,
                state.liquidity,
                state.amountSpecifiedRemaining,
                // state.feeGrowthGlobalX128
                fee
            );

            state.amountSpecifiedRemaining -= step.amountIn + step.feeAmount;
            state.amountCalculated += step.amountOut;
            state.tick = TickMath.getTickAtSqrtRatio(state.sqrtPriceX96);

            // fee updates
            if (state.liquidity > 0) {
                state.feeGrowthGlobalX128 += InternalMath.mulDivision(
                    step.feeAmount,
                    FixedPoint128.Q128,
                    _liq
                );
            }

            if (state.sqrtPriceX96 == step.sqrtPriceNextX96) {
                if (step.initialized) {
                    int128 liqDelta = ticks.cross(
                        step.nextTick,
                        direction ? state.feeGrowthGlobalX128 : feeGrowthGlobal0x128, 
                        direction ? feeGrowthGlobal1x128 : state.feeGrowthGlobalX128
                    );

                    if (direction) liqDelta = -liqDelta;

                    state.liquidity = LiquidityMath.addLiquidity(state.liquidity, liqDelta);

                    if (state.liquidity == 0) revert UniswapV3SimulatorPool__InsufficientLiquidity(state.liquidity);
                }

                state.tick = direction ? step.nextTick - 1 : step.nextTick;
            } else if (state.sqrtPriceX96 != step.sqrtPriceStartX96) {
                state.tick = TickMath.getTickAtSqrtRatio(state.sqrtPriceX96);
            }
        }

        // @audit-info oracla functionality will change this scope.
        if (slot.tick != state.tick) {
            (uint16 newObservationIndex, uint16 newCardinality) = observations.write(
                slot.observationIndex, slot.observationCardinality,
                slot.nextObservationCardinality, slot.tick,
                _timeStamp()
            );
            // observation functionality.
            (slot0.tick, slot0.sqrtPriceX96, slot0.observationIndex, slot0.nextObservationCardinality) =
                (state.tick, state.sqrtPriceX96, newObservationIndex, newCardinality);
        }


        /////////////////////////////////////////////////////////

        if (_liq != state.liquidity) liquidity = state.liquidity;

        if (direction) feeGrowthGlobal0x128 = state.feeGrowthGlobalX128;
        else feeGrowthGlobal1x128 = state.feeGrowthGlobalX128;

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

    
    function observe(uint32[] calldata secondsAgos)
    public
    returns (int56[] memory tickCumulatives)
    {
        return
            observations.observe(
                _timeStamp(),
                slot0.tick,
                slot0.observationCardinality,
                slot0.observationIndex,
                secondsAgos
            );
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


    /// @notice use case : when we want to change the position.
    /// @param params is the position detail that we want to change for the position.
    /// @return position which is the storage position based on the owner and tick data.
    /// @return amount0 the amount of token0 owed to the pool, negative if the pool should pay the recipient
    /// @return amount1 the amount of token1 owed to the pool, negative if the pool should pay the recipient
    function _modifyPosition(ModifyPositionParams memory params)
    internal
    returns (Position.Info storage position, int256 amount0, int256 amount1) 
    {
        // gas optimizations
        Slot0 memory slot0_ = slot0;
        uint256 feeGrowthGlobal0X128_ = feeGrowthGlobal0x128;
        uint256 feeGrowthGlobal1X128_ = feeGrowthGlobal1x128;

        position = positions.get(
            params.owner,
            params.lowerTick,
            params.upperTick
        );

        bool flippedLower = ticks.update(
            params.lowerTick,
            slot0_.tick,
            int128(params.liquidityDelta),
            feeGrowthGlobal0X128_,
            feeGrowthGlobal1X128_,
            false
        );
        bool flippedUpper = ticks.update(
            params.upperTick,
            slot0_.tick,
            int128(params.liquidityDelta),
            feeGrowthGlobal0X128_,
            feeGrowthGlobal1X128_,
            true
        );

        if (flippedLower) {
            tickBitmap.flipTick(params.lowerTick, int24(tickSpace));
        }

        if (flippedUpper) {
            tickBitmap.flipTick(params.upperTick, int24(tickSpace));
        }

        (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) = ticks
            .getFeeGrowthInside(
                params.lowerTick,
                params.upperTick,
                slot0_.tick,
                feeGrowthGlobal0X128_,
                feeGrowthGlobal1X128_
            );

        position.update(
            params.liquidityDelta,
            feeGrowthInside0X128,
            feeGrowthInside1X128
        );

        if (slot0_.tick < params.lowerTick) {
            amount0 = InternalMath.calculateDeltaToken0(
                TickMath.getSqrtRatioAtTick(params.lowerTick),
                TickMath.getSqrtRatioAtTick(params.upperTick),
                params.liquidityDelta
            );
        } else if (slot0_.tick < params.upperTick) {
            amount0 = InternalMath.calculateDeltaToken0(
                slot0_.sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(params.upperTick),
                params.liquidityDelta
            );

            amount1 = InternalMath.calculateDeltaToken1(
                TickMath.getSqrtRatioAtTick(params.lowerTick),
                slot0_.sqrtPriceX96,
                params.liquidityDelta
            );

            liquidity = LiquidityMath.addLiquidity(
                liquidity,
                params.liquidityDelta
            );
        } else {
            amount1 = InternalMath.calculateDeltaToken1(
                TickMath.getSqrtRatioAtTick(params.lowerTick),
                TickMath.getSqrtRatioAtTick(params.upperTick),
                params.liquidityDelta
            );
        }
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


    function _timeStamp() private view returns(uint32) {
        return uint32(block.timestamp);        
    }

}