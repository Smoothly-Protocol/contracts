// SPDX-License-Identifier: UNLICENSED 
pragma solidity ^0.8.16;

import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/utils/Strings.sol";
import "Solidity-RLP/RLPReader.sol";
import "./MPTVerifier.sol";
import "hardhat/console.sol";

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
  mapping(address => mapping(uint => mapping(bytes => bool))) claimExit;

  event ValidatorRegistered(address indexed eth1_addr, string validator);
  event ValidatorDeactivated(string validator);
  event Withdrawal(address indexed eth1_addr, string indexed pubKey, uint256 value);
  event StakeAdded(address indexed eth1_addr, string indexed pubKey, uint256 value);

  function registerBulk(bytes[] memory pubKeys) external payable {
    require(msg.value == (STAKE_FEE * pubKeys.length), "not enough eth send");
    for(uint i; i < pubKeys.length; i++) {
      register(pubKeys[i]);
    }	
  }

  function register(bytes memory pubKey) internal {
    require(pubKey.length == 98, "pubKey with wrong format");
    require(pubKey[0] == "0", "make sure it uses 0x");
    require(pubKey[1] == "x", "make sure it uses 0x");
    totalStake += STAKE_FEE;
    emit ValidatorRegistered(msg.sender, string(pubKey));
  }


  // TODO: Test for reentrancy
  function withdrawRewards(ProofData memory data) external {
    MerkleProof memory proof = buildProof(data); 
    require(verifyProof(proof), "Validator not registered");
    require(!claimedWithdrawal[msg.sender][EPOCH], "Already claimed withdrawal for current epoch");
    RLPReader.RLPItem[] memory validators = data.expectedValue.toRlpItem().toList();
    uint tRewards;

    // Calculate rewards for all validators
    for(uint i = 0; i < validators.length; ++i) {
      RLPReader.RLPItem[] memory validator = validators[i].toList(); 
      // Validator needs to be active
      if(validator[5].toBoolean()) {
        uint vRewards = validator[1].toUint();
        tRewards += vRewards;    
        emit Withdrawal(msg.sender, string(validator[0].toBytes()), vRewards);
      }
    }

    // Send Funds
    claimedWithdrawal[msg.sender][EPOCH] = true;
    require(tRewards > 0, "0 Rewards or inactive validators");
    (bool sent, ) = payable(msg.sender).call{value: tRewards, gas: 2300}("");
    require(sent, "Failed to send Ether");
  }

  // TODO: Test for reentrancy
  function exit(ProofData memory data, bytes[] memory pubKeys) external {
    MerkleProof memory proof = buildProof(data); 
    require(verifyProof(proof), "Validator not registered");
    RLPReader.RLPItem[] memory validators = data.expectedValue.toRlpItem().toList();
    uint tRewards;
    uint tStake;

    // Exit 
    for(uint i = 0; i < pubKeys.length; ++i) {
      RLPReader.RLPItem[] memory validator = findValidator(pubKeys[i], validators); 
      require(claimExit[msg.sender][EPOCH][validator[0].toBytes()], "Exit not allowed");
      tRewards += validator[1].toUint(); 
      tStake += validator[4].toUint();
      claimExit[msg.sender][EPOCH][validator[0].toBytes()] = false;
      emit ValidatorDeactivated(string(pubKeys[i]));
    }

    // Send Funds
    uint total = tRewards + tStake;
    if(total > 0) {
      (bool sent, ) = payable(msg.sender).call{value: total, gas: 2300}("");
      require(sent, "Failed to send Ether");
    }
  }

  function reqExit(bytes[] memory pubKeys) external {
    for(uint i = 0; i < pubKeys.length; ++i) {
      claimExit[msg.sender][EPOCH + 1][pubKeys[i]] = true;
    } 
  }

  function addStake(ProofData memory data, bytes memory pubKey) external payable {
    MerkleProof memory proof = buildProof(data); 
    require(verifyProof(proof), "Validator not registered");
    require(msg.value > 0, "0 amount");
    RLPReader.RLPItem[] memory validators = data.expectedValue.toRlpItem().toList();
    RLPReader.RLPItem[] memory validator = findValidator(pubKey, validators); 
    require((msg.value + validator[4].toUint()) <= STAKE_FEE, "Stake fee too big");
    emit StakeAdded(msg.sender, string(pubKey), msg.value); 
  }

  function setROOT(bytes32 _root) external onlyOwner {
    ROOT = _root;
    EPOCH++;
  }

  function findValidator(
    bytes memory pubKey, 
    RLPReader.RLPItem[] memory validators
  ) internal pure returns(RLPReader.RLPItem[] memory) {
    for(uint i = 0; i < validators.length; ++i) {
      RLPReader.RLPItem[] memory validator = validators[i].toList(); 
      if(keccak256(validator[0].toBytes()) == keccak256(pubKey)) {
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
