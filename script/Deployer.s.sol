// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/SmoothlyPool.sol";

contract Deployer is Script { 
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("OWNER");
    vm.startBroadcast(deployerPrivateKey);

    new SmoothlyPool();

    vm.stopBroadcast();
  }
}