# NFTFactory

Solidity contracts used in [Pawnfi](https://www.pawnfi.com/) .

## Overview

The NFTFactory contract provides a seamless exchange mechanism for NFTs and P-Token, allowing users to quickly and easily swap between the two forms of assets. Additionally, the contract offers a suite of advanced features such as NFT flash trading, consignment, and leverage to facilitate a range of exchange scenarios and business use cases.

## Audits

- PeckShield ( - ) : [report](./audits/audits.pdf) (Also available in Chinese in the same folder)

## Contracts

### Installation

- To run nftfactory, pull the repository from GitHub and install its dependencies. You will need [npm](https://docs.npmjs.com/cli/install) installed.

```bash
git clone https://github.com/PawnFi/NFTFactory.git
cd NFTFactory
npm install 
```
- Create an enviroment file named `.env` and fill the next enviroment variables

```
# Import private key
PRIVATEKEY= your private key  

# Add Infura provider keys
MAINNET_NETWORK=https://mainnet.infura.io/v3/YOUR_API_KEY
GOERLI_NETWORK=https://goerli.infura.io/v3/YOUR_API_KEY

```

### Compile

```
npx hardhat compile
```



### Local deployment

In order to deploy this code to a local testnet, you should install the npm package `@pawnfi/nft-factory` and import the PTokenFactory bytecode located at
`@pawnfi/nft-factory/artifacts/contracts/PTokenFactory.sol/PTokenFactory.json`.
For example:

```typescript
import {
  abi as FACTORY_ABI,
  bytecode as FACTORY_BYTECODE,
} from '@pawnfi/nft-factory/artifacts/contracts/PTokenFactory.sol/PTokenFactory.json'

// deploy the bytecode
```

This will ensure that you are testing against the same bytecode that is deployed to mainnet and public testnets, and all Pawnfi code will correctly interoperate with your local deployment.

### Using solidity interfaces

The Pawnfi NFTFactory interfaces are available for import into solidity smart contracts via the npm artifact `@pawnfi/nft-factory`, e.g.:

```solidity
import '@pawnfi/nft-factory/contracts/interfaces/IPToken.sol';

contract MyContract {
  IPToken pool;

  function doSomethingWithPool() {
    // pool.deposit(...);
  }
}

```

## License

- (c) Pawnfi Ltd., 2023 - [All rights reserved](https://github.com/PawnFi/NFTFactory/blob/main/LICENSE).


## Discussion

For any concerns with the protocol, open an issue or visit us on [Discord](https://discord.com/invite/pawnfi) to discuss.

For security concerns, please email [support@security.pawnfi.com](mailto:support@security.pawnfi.com).

_© Copyright 2023, Pawnfi Ltd._
