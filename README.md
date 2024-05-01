# This repo is a work in progress, and contracts have not been audited.

![header](https://github.com/ParsaAminpour/DeFi__UniswapV3Simulator/assets/77713904/25f1f76c-2e7f-4aa9-a8f7-22852ae6605b)

# UniswapV3 Simulator
UniswapV3 Simulator based on its name is a swap project whose architecture is broadly based on the UniswapV3.
All algorithms associated with this project are based on what is happening in UniswapV3 behind the scenes.

For a better understanding of the swap and add liquidity process you could go to [this](https://github.com/ParsaAminpour/DeFi__UniswapV3Simulator/tree/main/algorithm-docs) directory to see the calculations.

NOTE: All resources that I used to build this project were adjusted at the end of this readme.

## Environment Variables

To run this project via foundry, you will need to add the following environment variables to your .env file with these names (Choose the appropriate one based on the network that you want to interact with)

[`ALCHEMY_API_KEY`](https://dashboard.alchemy.com/)
[`ALCHEMY_ENDPOINT`](https://dashboard.alchemy.com/)
[`ETHERSCAN_API_KEY=`](https://etherscan.io/)
`PRIVATE_KEY`


## Deployment

To deploy this project run

```bash
  forge script script/UniswapV3SimulatorDeployer.s.sol --rpc-url <RPC-URL> --broadcast --verify
```

## Running Tests

To run tests, run the following command

```bash
  forge test -vvv
```
To get test coverages run:
``` bash
  forge coverage
```

## Authors

- [ParsaAmini](https://www.github.com/ParsaAminpour)


## Resources
- [UniswapV3 Development Book](https://uniswapv3book.com/index.html)

- [UniswapV3 Algorithms Diagram](https://www.youtube.com/watch?v=WW_xRGXSr7Q&list=PLO5VPQH6OWdXp2_Nk8U7V-zh7suI05i0E&pp=iAQB)

- [Uniswap Docs](https://docs.uniswap.org/contracts/v4/overview)
