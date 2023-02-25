import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-preprocessor";
import "hardhat-gas-reporter";
import fs from "fs";
import * as dotenv from 'dotenv'
dotenv.config()

function getRemappings() {
  return fs
  .readFileSync("remappings.txt", "utf8")
  .split("\n")
  .filter(Boolean) // remove empty lines
  .map((line) => line.trim().split("="));
}

const config: HardhatUserConfig = {
  networks: {
    hardhat: {
    },
    goerli: {
      url: process.env.GOERLI,
      accounts: [process.env.OWNER]
    }
  },
  solidity: "0.8.16",
  preprocess: {
    eachLine: (hre) => ({
      transform: (line: string) => {
        if (line.match(/^\s*import /i)) {
          for (const [from, to] of getRemappings()) {
            if (line.includes(from)) {
              line = line.replace(from, to);
              break;
            }
          }
        }
        return line;
      },
    }),
  },
  paths: {
    sources: "./src",
    tests: "./hardhat/test",
    cache: "./cache_hardhat",
  },
  gasReporter: {
    enabled: true
  }
};

export default config;
