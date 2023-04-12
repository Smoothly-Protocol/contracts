import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-gas-reporter";
import * as dotenv from 'dotenv'
dotenv.config()

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
  solidity: "0.8.16",
  paths: {
    sources: "./src",
    tests: "./test",
    cache: "./cache",
  },
  gasReporter: {
    enabled: true
  },
  mocha: {
    timeout: 100000
  } 
};

export default config;
