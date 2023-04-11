// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/SmoothlyPoolV2.sol";

contract SyncTest is Script { 
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("OWNER");
    vm.startBroadcast(deployerPrivateKey);

    SmoothlyPoolV2 pool = SmoothlyPoolV2(payable(0x56EE0A17812D7CF5f2Db4ce892e4f2a211575132));

    uint256[] memory validators = new uint256[](1);
    validators[0] = 10987;
    pool.registerBulk{value: 0.65 ether}(validators);

    vm.stopBroadcast();
  }
}
