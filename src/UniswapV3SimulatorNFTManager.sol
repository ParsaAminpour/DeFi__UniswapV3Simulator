// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC721} from "@solmate/src/tokens/ERC721.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IUniswapV3Manager } from "./interfaces/IUniswapV3Manager.sol";
import { IUniswapV3Pool } from "./interfaces/IUniswapV3Pool.sol";
import { PoolAddress } from "./libraries/PoolAddress.sol";
import {TickMath} from "./libraries/TickMath.sol";
import {LiquidityMath} from "./libraries/LiquidityMath.sol";
import { NFTRenderer } from "./libraries/NFTRenderer.sol";

contract NFTManager is ERC721{
    using SafeERC20 for IERC20;

    error NFTManager__NotAuthorized();
    error NFTManager__NotEnoughLiquidity();
    error NFTManager__PositionNotCleared();
    error NFTManager__SlippageCheckFailed(uint256 amount0, uint256 amount1);
    error NFTManager__WrongToken();

    event AddLiquidity(
        uint256 indexed tokenId,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    );

    event RemoveLiquidity(
        uint256 indexed tokenId,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    );

    struct TokenPosition {
        address pool;
        int24 lowerTick;
        int24 upperTick;
    }

    struct MintParams {
        address recipient;
        address tokenA;
        address tokenB;
        uint24 fee;
        int24 lowerTick;
        int24 upperTick;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
    }

    struct AddLiquidityParams {
        uint256 tokenId;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
    }

    struct CollectParams {
        uint256 tokenId;
        uint128 amount0;
        uint128 amount1;
    }

    struct AddLiquidityInternalParams {
        IUniswapV3Pool pool;
        int24 lowerTick;
        int24 upperTick;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
    }

    struct RemoveLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
    }

    uint256 public totalSupply;
    uint256 private nextTokenId;

    address public immutable factory;

    // To keep the links between pool liquidity positions and NFTs.
    // the mapping links NFT IDs to the position data that is required to find a liquidity position.
    mapping(uint256 => TokenPosition) public positions;

    modifier isApprovedOrOwner(uint256 tokenId) {
        address owner = ownerOf(tokenId);
        if (
            msg.sender != owner &&
            !isApprovedForAll[owner][msg.sender] &&
            getApproved[tokenId] != msg.sender
        ) revert NFTManager__NotAuthorized();

        _;
    }


    constructor(address factoryAddress)
        ERC721("UniswapV3 NFT Positions", "UNIV3")
    {
        factory = factoryAddress;
    }


    function tokenURI(uint256 _tokenId)
    public
    view
    override
    returns (string memory)
    {
        // NFTRenderer will adjust in here.
        TokenPosition memory position = positions[_tokenId];
        if (position.pool == address(0)) revert NFTManager__WrongToken();

        IUniswapV3Pool pool = IUniswapV3Pool(position.pool);

        return NFTRenderer.render(
            NFTRenderer.RenderParams({
                owner: address(this),
                pool: position.pool,
                lowerTick: position.lowerTick,
                upperTick: position.upperTick,
                fee: pool.fee()
            })
        ); 
    }


    /// @param params is struct compressed data appropriate for NFT position minting process.
    /// @return tokenId associated with this minting.
    function mint(MintParams calldata params) public returns (uint256 tokenId) {
        IUniswapV3Pool pool = getPool(params.tokenA, params.tokenB, params.fee);

        (uint128 liquidity, uint256 amount0, uint256 amount1) = _addLiquidity(
            AddLiquidityInternalParams({
                pool: pool,
                lowerTick: params.lowerTick,
                upperTick: params.upperTick,
                amount0Desired: params.amount0Desired,
                amount1Desired: params.amount1Desired,
                amount0Min: params.amount0Min,
                amount1Min: params.amount1Min
            })
        );

        tokenId = nextTokenId + 1;
        totalSupply ++;

        TokenPosition memory newPosition = TokenPosition({
            pool: address(pool),
            lowerTick: params.lowerTick,
            upperTick: params.upperTick
        });

        positions[tokenId] = newPosition;
        _safeMint(
            params.recipient,
            tokenId,
            abi.encode(
                IUniswapV3Pool.CallbackData({
                    token0: params.tokenA,
                    token1: params.tokenB,
                    payer: params.recipient
                }))
            );

        emit AddLiquidity(tokenId, liquidity, amount0, amount1);
    }


    /// @notice to add liquidity to an existing position, in the case when we want to add more liquidity in a position that already has some.
    /// @notice we won't mint NFT here cuz we have already minted and we just want to add/increase liquidity to pre-minted position.
    function addLiquidity(AddLiquidityParams calldata params, bytes calldata _data)
    public
    returns (uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        TokenPosition memory tokenPosition = positions[params.tokenId];
        if (tokenPosition.pool == address(0x00)) revert NFTManager__WrongToken();

        (liquidity, amount0, amount1) = _addLiquidity(
            AddLiquidityInternalParams({
                pool: IUniswapV3Pool(tokenPosition.pool),
                lowerTick: tokenPosition.lowerTick,
                upperTick: tokenPosition.upperTick,
                amount0Desired: params.amount0Desired,
                amount1Desired: params.amount1Desired,
                amount0Min: params.amount0Min,
                amount1Min: params.amount1Min
            })
        );

        emit AddLiquidity(params.tokenId, liquidity, amount0, amount1);
    }


    // TODO: add slippage check
    /// @param params which is the compressed structure just associated to removeLiquidity purpose.
    /// @return amount0 The amount of token0 sent to the recipient
    /// @return amount1 The amount of token1 sent to the recipient 
    function removeLiquidity(RemoveLiquidityParams memory params)
        public
        isApprovedOrOwner(params.tokenId)
        returns (uint256 amount0, uint256 amount1)
    {
        TokenPosition memory position = positions[params.tokenId];
        if (position.pool == address(0)) revert NFTManager__WrongToken();

        IUniswapV3Pool pool = IUniswapV3Pool(position.pool);
        (uint128 currentLiquidity, , , , ) = pool.positions(
            getPoolPositionKey(position));
        
        // ensure that a position has enough liquidity to burn.
        if (currentLiquidity < params.liquidity) revert NFTManager__NotEnoughLiquidity();

        // burn liquidity, NOT BURN NFT!
        (amount0, amount1) = pool.burn(position.lowerTick, position.upperTick, params.liquidity);

        emit RemoveLiquidity(params.tokenId, params.liquidity, amount0, amount1);
    }


    /// @dev this function will burn NFT, NOT burn liquidity!
    /// @notice if we want to burn an NFT, we need to:
    ///     call removeLiquidity and remove the entire position liquidity;
    ///     call collect to collect the tokens after burning the position;
    ///     call burn to burn the token.
    function burn(uint256 _tokenId) public isApprovedOrOwner(_tokenId) {
        TokenPosition memory position = positions[_tokenId];
        if (position.pool == address(0)) revert NFTManager__WrongToken();

        IUniswapV3Pool pool = IUniswapV3Pool(position.pool);

        (uint128 currentLiquidity, , , uint128 tokenOwed0, uint128 tokenOwed1) = pool.positions(
            getPoolPositionKey(position)
        );
        if (currentLiquidity != 0 || tokenOwed0 != 0 || tokenOwed1 != 0) revert NFTManager__PositionNotCleared();

        delete positions[_tokenId];
        _burn(_tokenId);
        totalSupply --;
    }


    function collect(CollectParams memory params)
    public
    isApprovedOrOwner(params.tokenId)
    returns (uint128 amount0, uint128 amount1)
    {
        TokenPosition memory position = positions[params.tokenId];
        if (position.pool == address(0)) revert NFTManager__WrongToken();

        IUniswapV3Pool pool = IUniswapV3Pool(position.pool);

        (amount0, amount1) = pool.collect(
            msg.sender, position.lowerTick, position.upperTick, params.amount0, params.amount1
        );
    }


    // callbacks
    function uniswapV3MintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) public {
        IUniswapV3Pool.CallbackData memory extra = abi.decode(
            data,
            (IUniswapV3Pool.CallbackData)
        );

        IERC20(extra.token0).safeTransferFrom(extra.payer, msg.sender, amount0);
        IERC20(extra.token1).safeTransferFrom(extra.payer, msg.sender, amount1);
    }


    //////////////////////////////////////////////////////
    //.............. Internal Functions ..................
    //////////////////////////////////////////////////////
    function _addLiquidity(AddLiquidityInternalParams memory params)
        internal
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        (uint160 sqrtPriceX96, , , , , ) = params.pool.slot0();

        liquidity = LiquidityMath.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(params.lowerTick),
            TickMath.getSqrtRatioAtTick(params.upperTick),
            params.amount0Desired,
            params.amount1Desired
        );

        (amount0, amount1) = params.pool.mint(
            address(this),
            params.lowerTick,
            params.upperTick,
            liquidity,
            abi.encode(
                IUniswapV3Pool.CallbackData({
                    token0: params.pool.token0(),
                    token1: params.pool.token1(),
                    payer: msg.sender
                })
            )
        );

        if (amount0 < params.amount0Min || amount1 < params.amount1Min)
            revert NFTManager__SlippageCheckFailed(amount0, amount1);
    }



    function getPool(
        address token0,
        address token1,
        uint24 fee
    ) internal view returns (IUniswapV3Pool pool) {
        (token0, token1) = token0 < token1
            ? (token0, token1)
            : (token1, token0);
        pool = IUniswapV3Pool(
            PoolAddress.computeAddress(factory, token0, token1, fee)
        );
    }


    function getPoolPositionKey(TokenPosition memory _tokenPosition) internal view returns(bytes32 key) {
        key = keccak256(
            abi.encodePacked(
                address(this), _tokenPosition.lowerTick, _tokenPosition.upperTick
            )
        );
    }


    function positionKey(TokenPosition memory position)
    internal
    pure
    returns (bytes32 key)
    {}
}