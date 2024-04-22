
![Logo](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/th5xamgrr6se0x5ro4g6.png)

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

- [@octokatherine](https://www.github.com/octokatherine)


## Resources
....