# This repo is a work in progress, and contracts have not been audited.

![header](https://github.com/ParsaAminpour/DeFi__UniswapV3Simulator/assets/77713904/25f1f76c-2e7f-4aa9-a8f7-22852ae6605b)

# UniswapV3 Simulator
UniswapV3 Simulator on its name is a swap project which its architecture is broadly based on the UniswapV3.
All aglorithms associated with this project is based on what is happening in UniswapV3 behind the scene.

For better understanding the swap and add liquidity process you could go to `this` directory to see the calculations.

NOTE: All resources that I used to build this project adjusted at the end of this readme.

## Environment Variables

To run this project via foundry, you will need to add the following environment variables to your .env file (Choose appropriate on based on the network that you want interact with)

`ALCHEMY_API_KEY`
`ALCHEMY_ENDPOINT`
`ETHERSCAN_API_KEY`
`YOU-TEST-WALLET-PRIVATE-KEY`


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


## Optimizations

DETAILS WILL ADD ASAP.


## Authors

- [ParsaAmini](https://www.github.com/ParsaAminpour)


## Resources
[UniswapV3 Development Book](https://uniswapv3book.com/index.html)

[UniswapV3 Algorithms Diagram](https://www.youtube.com/watch?v=WW_xRGXSr7Q&list=PLO5VPQH6OWdXp2_Nk8U7V-zh7suI05i0E&pp=iAQB)
