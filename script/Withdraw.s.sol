// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/SmoothlyPool.sol";

contract Withdrawal is Script { 
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("OWNER");
    vm.startBroadcast(deployerPrivateKey);

    SmoothlyPool pool = SmoothlyPool(payable(0xBc18866BAaAa12201d977e5ac71eC575D4d06e61));
    pool.withdrawFees();

    vm.stopBroadcast();
  }
}
