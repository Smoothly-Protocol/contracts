import { HardhatUserConfig } from "hardhat/config";
import "@nomiclabs/hardhat-etherscan";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-gas-reporter";
import * as dotenv from 'dotenv'
dotenv.config()

import { deployer } from './scripts/deploy';

task("deploy", "Deploys Smoothly Protocol")
.addParam("multisig", "The multisig address account")
.setAction(async (taskArgs) => {
  await deployer(taskArgs.multisig);
});

const config: HardhatUserConfig = {
  networks: {
    hardhat: {
      accounts: {
        count: 10
      }
    },
    goerli: {
      url: process.env.GOERLI,
      accounts: [process.env.OWNER]
    }
  },
  solidity: "0.8.19",
  paths: {
    sources: "./src",
    tests: "./test",
    cache: "./cache",
  },
  etherscan: {
    apiKey: {
      goerli: process.env.ETHERSCAN_API
    }
  },
  gasReporter: {
    enabled: true
  },
  mocha: {
    timeout: 100000
  } 
};

export default config;
