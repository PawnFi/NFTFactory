require('dotenv').config()
const PRIVATEKEY = process.env.PRIVATEKEY;
const GOERLI_NETWORK = process.env.GOERLI_NETWORK;

require("@nomicfoundation/hardhat-toolbox");

module.exports = {
	solidity: {
		compilers: [{
			version: "0.8.17",
			settings: {
				optimizer: {
					enabled: true,
					runs: 200
				}
			},
		}]
	},
	networks: {
		goerli: {
			url: GOERLI_NETWORK,
			chainId: 5,
			gasPrice: 'auto',
			accounts: [PRIVATEKEY],
		},
		mumbai: {
			url: `${process.env.MUMBAI_NETWORK}`,
			chainId: 80001,
			gasPrice: 'auto',
			accounts: [`${process.env.PRIVATEKEY}`],
		}
	}
};