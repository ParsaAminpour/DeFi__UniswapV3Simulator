// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC721} from "@solmate/src/tokens/ERC721.sol";
import { IUniswapV3Manager } from "./interfaces/IUniswapV3Manager.sol";
import { IUniswapV3Pool } from "./interfaces/IUniswapV3Pool.sol";

contract NFTManager is ERC721{
    error NotAuthorized();
    error NotEnoughLiquidity();
    error PositionNotCleared();
    error SlippageCheckFailed(uint256 amount0, uint256 amount1);
    error WrongToken();

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

    uint256 public totalSupply;
    uint256 private nextTokenId;

    address public immutable factory;

    // To keep the links between pool liquidity positions and NFTs.
    mapping(uint256 => TokenPosition) public positions;

    modifier isApprovedOrOwner(uint256 tokenId) {
        address owner = ownerOf(tokenId);
        if (
            msg.sender != owner &&
            !isApprovedForAll[owner][msg.sender] &&
            getApproved[tokenId] != msg.sender
        ) revert NotAuthorized();

        _;
    }

    constructor(address factoryAddress)
        ERC721("UniswapV3 NFT Positions", "UNIV3")
    {
        factory = factoryAddress;
    }

    function tokenURI(uint256 tokenId)
    public
    view
    override
    returns (string memory)
    {}

    function mint(MintParams calldata params) public returns (uint256 tokenId) {

    }

    function addLiquidity(AddLiquidityParams calldata params)
    public
    returns (
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    )
    {}

    // function removeLiquidity(RemoveLiquidity memory params)
    // public
    // isApprovedOrOwner(params.tokenId)
    // returns (uint256 amount0, uint256 amount1)
    // {}

    function collect(CollectParams memory params)
    public
    isApprovedOrOwner(params.tokenId)
    returns (uint128 amount0, uint128 amount1)
    {}

    /// @notice if we want to burn an NFT, we need to:
    ///     call removeLiquidity and remove the entire position liquidity;
    ///     call collect to collect the tokens after burning the position;
    ///     call burn to burn the token.
    function burn(uint256 tokenId) public isApprovedOrOwner(tokenId) {}


    // callbacks
    function uniswapV3MintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) public {}

    
    // internals
    function _addLiquidity(AddLiquidityInternalParams memory params)
    internal
    returns (
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    )
    {}

    function getPool(
        address token0,
        address token1,
        uint24 fee
    ) internal view returns (IUniswapV3Pool pool) {}

    function poolPositionKey(TokenPosition memory position)
    internal
    view
    returns (bytes32 key)
    {}

    function positionKey(TokenPosition memory position)
    internal
    pure
    returns (bytes32 key)
    {}
}