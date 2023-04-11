// SPDX-License-Identifier: UNLICENSED 
pragma solidity ^0.8.16;

import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/utils/Strings.sol";
import "Solidity-RLP/RLPReader.sol";
import "./MPTVerifier.sol";
//import "hardhat/console.sol";

contract SmoothlyPoolMPT is MPTVerifier, Ownable {
  using RLPReader for RLPReader.RLPItem;
  using RLPReader for bytes;
  using Strings for address;

  uint constant STAKE_FEE = 0.65 ether;
  uint public EPOCH = 0;
  uint public totalStake;
  bytes32 public ROOT = hex'56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421'; // Empty

  struct ProofData {
    bytes[] proof;
    bytes expectedValue; 
  }

  mapping(address => mapping(uint => bool)) claimedWithdrawal;
  mapping(address => mapping(uint => mapping(uint => bool))) claimExit;

  event ValidatorRegistered(address indexed eth1, uint256 validatorIndex);
  event ValidatorDeactivated(address indexed eth1, uint validatorIndex);
  event Withdrawal(address indexed eth1, uint validatorIndex, uint256 value);
  event StakeAdded(address indexed eth1, uint validatorIndex, uint256 value);

  function registerBulk(uint[] memory validatorIndex) external payable {
    require(msg.value == (STAKE_FEE * validatorIndex.length), "not enough eth send");
    for(uint i; i < validatorIndex.length; i++) {
      totalStake += STAKE_FEE;
      emit ValidatorRegistered(msg.sender, validatorIndex[i]);
    }	
  }

  // TODO: Test for reentrancy
  function withdrawRewards(ProofData memory data) external {
    MerkleProof memory proof = buildProof(data); 
    require(verifyProof(proof), "Incorrect proof");
    require(!claimedWithdrawal[msg.sender][EPOCH], "Already claimed withdrawal for current epoch");
    RLPReader.RLPItem[] memory validators = data.expectedValue.toRlpItem().toList();
    uint tRewards;

    // Calculate rewards for all validators
    for(uint i = 0; i < validators.length; ++i) {
      RLPReader.RLPItem[] memory validator = validators[i].toList(); 
      require(!claimExit[msg.sender][EPOCH][validator[0].toUint()], "Validator exited on current epoch");
      // Validator needs to be active
      if(validator[5].toBoolean()) {
        uint vRewards = validator[1].toUint();
        tRewards += vRewards;    
        emit Withdrawal(msg.sender, validator[0].toUint(), vRewards);
      }
    }

    // Send Funds
    claimedWithdrawal[msg.sender][EPOCH] = true;
    require(tRewards > 0, "0 Rewards or inactive validators");
    (bool sent, ) = payable(msg.sender).call{value: tRewards, gas: 2300}("");
    require(sent, "Failed to send Ether");
  }

  // TODO: Test for reentrancy
  function exit(ProofData memory data, uint[] memory indexes) external {
    MerkleProof memory proof = buildProof(data); 
    require(verifyProof(proof), "Incorrect proof");
    RLPReader.RLPItem[] memory validators = data.expectedValue.toRlpItem().toList();
    uint tRewards;
    uint tStake;

    // Exit 
    for(uint i = 0; i < indexes.length; ++i) {
      RLPReader.RLPItem[] memory validator = findValidator(indexes[i], validators); 
      require(validator[5].toBoolean(), "Validator is not active yet");
      require(claimExit[msg.sender][EPOCH][validator[0].toUint()], "Exit not allowed");
      tRewards += validator[1].toUint(); 
      tStake += validator[4].toUint();
      claimExit[msg.sender][EPOCH][validator[0].toUint()] = false;
      emit ValidatorDeactivated(msg.sender, indexes[i]);
    }

    // Send Funds
    uint total = tRewards + tStake;
    if(total > 0) {
      (bool sent, ) = payable(msg.sender).call{value: total, gas: 2300}("");
      require(sent, "Failed to send Ether");
    }
  }

  function reqExit(uint[] memory indexes) external {
    for(uint i = 0; i < indexes.length; ++i) {
      claimExit[msg.sender][EPOCH + 1][indexes[i]] = true;
    } 
  }

  function addStake(ProofData memory data, uint index) external payable {
    MerkleProof memory proof = buildProof(data); 
    require(verifyProof(proof), "Incorrect proof");
    require(msg.value > 0, "0 amount");
    RLPReader.RLPItem[] memory validators = data.expectedValue.toRlpItem().toList();
    RLPReader.RLPItem[] memory validator = findValidator(index, validators); 
    require((msg.value + validator[4].toUint()) <= STAKE_FEE, "Stake fee too big");
    emit StakeAdded(msg.sender, index, msg.value); 
  }

  function setROOT(bytes32 _root) external onlyOwner {
    ROOT = _root;
    EPOCH++;
  }

  function findValidator(
    uint index, 
    RLPReader.RLPItem[] memory validators
  ) internal pure returns(RLPReader.RLPItem[] memory) {
    for(uint i = 0; i < validators.length; ++i) {
      RLPReader.RLPItem[] memory validator = validators[i].toList(); 
      if(validator[0].toUint() == index) {
        return validator;
      }
    }
    revert("Validator not found");
  }

  function buildProof(ProofData memory data) internal view returns (MerkleProof memory) {
    return MerkleProof(
      ROOT,
      abi.encodePacked(keccak256(bytes(msg.sender.toHexString()))), 
      data.proof,
      0, 
      0, 
      data.expectedValue
    );
  }

  receive () external payable {
  }
}
