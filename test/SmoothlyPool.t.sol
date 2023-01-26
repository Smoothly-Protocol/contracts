// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/SmoothlyPool.sol";

contract SmoothlyPoolTest is Test, SmoothlyPool {
  // Contracts
  SmoothlyPool pool;

  // Declare events
  event logValidators(Validator[] v);
  event logUint(uint u);

  // Setting up testing environment
  function setUp() public {
    pool = new SmoothlyPool();
  }

  function testRegisters() public {
    bytes memory validator1 = "0xsdfklgjsdflkgjs";
    bytes memory validator2 = "aad7124198a7f1c4654dc924449fe7734470db03753b470ff91699cc248870e5f45460691099a68b16bff535d5020d61";
    bytes memory validator3 = "xxaad7124198a7f1c4654dc924449fe7734470db03753b470ff91699cc248870e5f45460691099a68b16bff535d5020d61";
    bytes memory validator4 = "00aad7124198a7f1c4654dc924449fe7734470db03753b470ff91699cc248870e5f45460691099a68b16bff535d5020d61";
    bytes memory validator5 = "0xaad7124198a7f1c4654dc924449fe7734470db03753b470ff91699cc248870e5f45460691099a68b16bff535d5020d61";

    vm.expectRevert(bytes('not enough eth send'));
    pool.register(validator1);
    vm.expectRevert(bytes('pubKey with wrong format'));
    pool.register{value: STAKE_FEE}(validator1);
    vm.expectRevert(abi.encodePacked("pubKey with wrong format"));
    pool.register{value: STAKE_FEE}(validator2);
    vm.expectRevert(abi.encodePacked("make sure it uses 0x"));
    pool.register{value: STAKE_FEE}(validator3);
    vm.expectRevert(abi.encodePacked("make sure it uses 0x"));
    pool.register{value: STAKE_FEE}(validator4);

    vm.expectEmit(true, true, true, true);
    emit ValidatorRegistered(msg.sender, string(validator5), 0);
    vm.startPrank(msg.sender);
    pool.register{value: STAKE_FEE}(validator5);
    vm.expectRevert(abi.encodePacked("validator exists"));
    pool.register{value: STAKE_FEE}(validator5);
    vm.stopPrank();
  }

  function testBulkRegister() public {
    string[3] memory validators = [
      "0xa99a76ed7796f7be22d5b7e85deeb7c5677e88e511e0b337618f8c4eb61349b4bf2d153f649f7b53359fe8b94a38e44c",
      "0xb89bebc699769726a318c8e9971bd3171297c61aea4a6578a7a4f94b547dcba5bac16a89108b6b6a1fe3695d1a874a0b",
      "0xa3a32b0f8b4ddb83f1a0a853d81dd725dfe577d4f4c3db8ece52ce2b026eca84815c1a7e8e92a4de3d755733bf7e4a9b"
    ];
    bytes[] memory arg = new bytes[](3);
    for(uint i; i < 3; i++) {
      arg[i] = bytes(validators[i]);
    }
    vm.expectEmit(true, true, true, true);
    emit ValidatorRegistered(msg.sender, validators[0], 0);
    vm.expectEmit(true, true, true, true);
    emit ValidatorRegistered(msg.sender, validators[1], 1);
    vm.expectEmit(true, true, true, true);
    emit ValidatorRegistered(msg.sender, validators[2], 2);
    vm.startPrank(msg.sender);
    pool.registerBulk{value: STAKE_FEE * 3}(arg);	
    vm.expectRevert(bytes('not enough eth send'));
    pool.registerBulk{value: STAKE_FEE * 2}(arg);	
    vm.stopPrank();
  }

  function testRebalance() public {
    bytes memory validator5 = "0xaad7124198a7f1c4654dc924449fe7734470db03753b470ff91699cc248870e5f45460691099a68b16bff535d5020d61";
    RebalanceUser[] memory r = new RebalanceUser[](1);
    r[0] = RebalanceUser(msg.sender, 0, 100, 0 , 0, true);
    vm.prank(msg.sender);
    pool.register{value: STAKE_FEE}(validator5);
    pool.rebalanceRewards(r, 0);		
    vm.prank(msg.sender);
    assertEq(pool.getValidators()[0].rewards, 100);
  }

  function testGetTRewardsForRebalance() public {
    string[7] memory validators = [
      "0xa99a76ed7796f7be22d5b7e85deeb7c5677e88e511e0b337618f8c4eb61349b4bf2d153f649f7b53359fe8b94a38e44c",
      "0xb89bebc699769726a318c8e9971bd3171297c61aea4a6578a7a4f94b547dcba5bac16a89108b6b6a1fe3695d1a874a0b",
      "0xa3a32b0f8b4ddb83f1a0a853d81dd725dfe577d4f4c3db8ece52ce2b026eca84815c1a7e8e92a4de3d755733bf7e4a9b",
      "0x88c141df77cd9d8d7a71a75c826c41a9c9f03c6ee1b180f3e7852f6a280099ded351b58d66e653af8e42816a4d8f532e",
      "0x81283b7a20e1ca460ebd9bbd77005d557370cabb1f9a44f530c4c4c66230f675f8df8b4c2818851aa7d77a80ca5a4a5e",
      "0xab0bdda0f85f842f431beaccf1250bf1fd7ba51b4100fd64364b6401fda85bb0069b3e715b58819684e7fc0b10a72a34",
      "0x9977f1c8b731a8d5558146bfb86caea26434f3c5878b589bf280a42c9159e700e9df0e4086296c20b011d2e78c27d373"
    ];
    RebalanceUser[] memory r = new RebalanceUser[](validators.length);
    vm.startPrank(msg.sender);
    for(uint i; i < validators.length; i++) {
      pool.register{value: STAKE_FEE}(bytes(validators[i]));	
      r[i] = RebalanceUser(msg.sender, i, 0.1 ether, i%2, 0, true);		
    }
    vm.expectRevert(abi.encodePacked("Validator reward balance is 0"));
    uint[] memory id = new uint[](1);
    id[0] = 3;
    pool.withdrawRewards(id);
    vm.stopPrank();
    payable(address(pool)).transfer(0.7 ether);
    // First week
    pool.rebalanceRewards(r, 0);	
    assertEq(pool.totalRewards(), 0.7 ether);
    assertEq(pool.totalStake(), 4.1 ether); 
    assertEq(pool.getRebalanceRewards(), 0.45 ether);
    // Second Week
    payable(address(pool)).transfer(4000);
    vm.prank(msg.sender);
    pool.withdrawRewards(id);
    assertEq(pool.getRebalanceRewards(), 4000 + 0.45 ether);
    assertEq(pool.totalRewards(), 0.6 ether);
  }

  function testSlashings() public {
    string memory validator = "0xa99a76ed7796f7be22d5b7e85deeb7c5677e88e511e0b337618f8c4eb61349b4bf2d153f649f7b53359fe8b94a38e44c";
    RebalanceUser[] memory r = new RebalanceUser[](1);
    vm.startPrank(msg.sender);
    pool.register{value: STAKE_FEE}(bytes(validator));
    r[0] = RebalanceUser(msg.sender, 0, 1000, 1, 1, true);		
    vm.stopPrank();
    vm.expectEmit(true, true, true, true);
    emit ValidatorDeactivated(validator);
    pool.rebalanceRewards(r, 0);	
  }

  function testAddStake() public {
    string memory validator = "0xa99a76ed7796f7be22d5b7e85deeb7c5677e88e511e0b337618f8c4eb61349b4bf2d153f649f7b53359fe8b94a38e44c";
    RebalanceUser[] memory r = new RebalanceUser[](1);
    vm.startPrank(msg.sender);
    pool.register{value: STAKE_FEE}(bytes(validator));
    r[0] = RebalanceUser(msg.sender, 0, 1000, 2, 0, true);		
    vm.stopPrank();
    pool.rebalanceRewards(r, 0);	
    vm.startPrank(msg.sender);
    assertEq(pool.getValidators()[0].stake, 0.35 ether);
    vm.expectRevert(bytes("Stake fee bigger than allowed"));
    uint[] memory ids = new uint[](1);
    for(uint i; i < 1; i++) {
      ids[i] = i;
    }
    pool.addStake{value: 0.31 ether}(ids);
    pool.addStake{value: 0.30 ether}(ids);
    assertEq(pool.getValidators()[0].stake, 0.65 ether);
    r[0] = RebalanceUser(msg.sender, 0, 1000, 0, 1, true);		
    vm.stopPrank();
    pool.rebalanceRewards(r, 0);	
    vm.prank(msg.sender);
    vm.expectRevert(bytes("Validator not allowed to add more stake"));
    pool.addStake{value: 0.15 ether}(ids);
  }

  function testExitProtocol() public {
    testGetTRewardsForRebalance();
    vm.startPrank(msg.sender);
    uint[] memory ids = new uint[](4);
    for(uint i; i < 4; i++) {
      ids[i] = i;
    }
    assertEq(pool.totalStake(), 4.1 ether); 
    emit logValidators(pool.getValidators());
    pool.exit(ids);
    emit logValidators(pool.getValidators());
    assertEq(pool.totalRewards(), 0.3 ether);
    assertEq(pool.totalStake(), 1.8 ether); 
    vm.stopPrank();
  }

  function testExitProtocolNonActiveUser() public {
    bytes memory validator = "0xaad7124198a7f1c4654dc924449fe7734470db03753b470ff91699cc248870e5f45460691099a68b16bff535d5020d61";
    RebalanceUser[] memory r = new RebalanceUser[](1);
    uint[] memory id = new uint[](1);
    id[0] = 0;
    vm.startPrank(msg.sender);
    pool.register{value: STAKE_FEE}(validator);
    r[0] = RebalanceUser(msg.sender, 0, 1000, 0, 0, false);		
    vm.stopPrank();
    payable(address(pool)).transfer(4000);
    pool.rebalanceRewards(r, 100);	
    vm.startPrank(msg.sender);
    vm.expectRevert(bytes("Validator not active"));
    pool.withdrawRewards(id); 
    pool.exit(id);
    vm.stopPrank();
    assertEq(pool.totalRewards(), 0);
    assertEq(pool.getRebalanceRewards(), 3900);
  }

  function testRebalanceNonActiveUserSlashed() public {
    string memory validator = "0xa99a76ed7796f7be22d5b7e85deeb7c5677e88e511e0b337618f8c4eb61349b4bf2d153f649f7b53359fe8b94a38e44c";
    RebalanceUser[] memory r = new RebalanceUser[](1);
    vm.startPrank(msg.sender);
    pool.register{value: STAKE_FEE}(bytes(validator));
    r[0] = RebalanceUser(msg.sender, 0, 1000, 0, 0, false);		
    vm.stopPrank();
    payable(address(pool)).transfer(4000);
    pool.rebalanceRewards(r, 0);	
    assertEq(pool.getRebalanceRewards(), 3000);
    vm.startPrank(msg.sender);
    r[0] = RebalanceUser(msg.sender, 0, 0, 1, 0, false);
    vm.stopPrank();
    pool.rebalanceRewards(r, 0);	
    vm.prank(msg.sender);
    assertEq(pool.getValidators()[0].rewards, 0);
    assertEq(pool.getRebalanceRewards(), 4000);
  }

  function testRebalanceWithFee() public {
    string memory validator = "0xa99a76ed7796f7be22d5b7e85deeb7c5677e88e511e0b337618f8c4eb61349b4bf2d153f649f7b53359fe8b94a38e44c";
    RebalanceUser[] memory r = new RebalanceUser[](1);
    vm.startPrank(msg.sender);
    pool.register{value: STAKE_FEE}(bytes(validator));
    r[0] = RebalanceUser(msg.sender, 0, 1000, 0, 0, true);		
    vm.stopPrank();
    payable(address(pool)).transfer(4000);
    pool.rebalanceRewards(r, 100);	
    pool.withdrawFees();
    assertEq(pool.getRebalanceRewards(), 2900);
  }
}
