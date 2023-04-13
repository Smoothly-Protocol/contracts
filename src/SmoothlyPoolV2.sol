// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.16;

/**
 * @title Smoothing Pool V2 Contract.
 * @notice This contract recieves and distributes all the rewards from registered 
 * validators evenly and smoothly.
 */

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract SmoothlyPoolV2 is Ownable {
  uint constant public STAKE_FEE = 0.065 ether;
  uint public epoch = 0;
  bytes32 public withdrawalsRoot;
  bytes32 public exitsRoot;
  bytes32 public stateRoot = hex'56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421'; // Empty

  /// @dev Flags registrant on epoch to prevent doble withdrawals 
  mapping(address => mapping(uint => bool)) claimedWithdrawal;
  /// @dev Flags registrant on epoch to prevent doble exits
  mapping(address => mapping(uint => bool)) claimedExit;

  event Registered(address indexed eth1, uint[] indexes);
  event RewardsWithdrawal(address indexed eth1, uint[] indexes, uint256 value);
  event StakeWithdrawal(address indexed eth1, uint[] indexes, uint256 value);
  event StakeAdded(address indexed eth1, uint index, uint256 value);
  event ExitRequested(address indexed eth1, uint[] indexes);
  event Epoch(uint indexed epoch, bytes32 withdrawalsRoot, bytes32 exitsRoot, bytes32 stateRoot);

  /**
   * @notice Register n amount of validators to the pool
   * @param indexes Validator indexes
   * @dev Backend verifies ownership of the validators 
   * This is intended to be called from the front-end, double checking
   * for ownership. Anyone registering unowned validators will lose their staking
   * funds and those will be distributed amongst the pool registrants.
   */
  function registerBulk(uint[] memory indexes) external payable {
    require(msg.value == (STAKE_FEE * indexes.length), "not enough eth send");
    emit Registered(msg.sender, indexes);
  }

  /**
   * @notice Withdraw rewards from the pool
   * @param proof Merkle Proof
   * @param rewards All rewards acumulated from all validators associated 
   * to an eth1 address
   * TODO: Test for reentrancy
   */
  function withdrawRewards(bytes32[] memory proof, uint[] memory indexes, uint rewards) external {
    bytes32 leaf = keccak256(bytes.concat(keccak256(
      abi.encode(
        msg.sender, 
        indexes,
        rewards
    ))));
    require(MerkleProof.verify(proof, withdrawalsRoot, leaf), "Incorrect proof");
    require(!claimedWithdrawal[msg.sender][epoch], "Already claimed withdrawal for current epoch");
    claimedWithdrawal[msg.sender][epoch] = true;
    _transfer(msg.sender, rewards);
    emit RewardsWithdrawal(msg.sender, indexes, rewards);
  }

  /**
  * @notice Withdraws stake on exit request
  * @param proof Merkle Proof
  * @param stake Amount of stake of all validators that requested exit on
  * previous epochs
  * @dev Registrants that don't request an exit of their validators
  * won't be included
  * TODO: Test for reentrancy
  */
  function withdrawStake(bytes32[] memory proof, uint[] memory indexes, uint stake) external {
    bytes32 leaf = keccak256(bytes.concat(keccak256(
      abi.encode(
        msg.sender, 
        indexes,
        stake
    ))));
    require(MerkleProof.verify(proof, exitsRoot, leaf), "Incorrect proof");
    require(!claimedExit[msg.sender][epoch], "Already claimed exit for current epoch");

    claimedExit[msg.sender][epoch] = true;
    _transfer(msg.sender, stake);
    emit StakeWithdrawal(msg.sender, indexes, stake);
  }

  /**
  * @notice Allows user to exit pool retrieving stake in next epoch 
  * @param indexes Validator indexes
  */
  function requestExit(uint[] memory indexes) external {
    emit ExitRequested(msg.sender, indexes);
  }

  /**
  * @notice Adds stake to a validator in the pool 
  * @param index Validator index
  * @dev Front-end needs to check for a valid validator call, otherwise funds
  * will get lost and added as rewards for registrants of the pool
  */
  function addStake(uint index) external payable {
    require(msg.value > 0, "0 amount");
    require(msg.value <= STAKE_FEE, "Stake fee too big");
    emit StakeAdded(msg.sender, index, msg.value); 
  }

  /** 
   * @notice Updates epoch number and Merkle root hashes 
   * @param _withdrawalsRoot Merkle root hash for withdrawals
   * @param _exitsRoot Merkle root hash for exits 
   * @param _stateRoot Merkle Patricia Trie root hash for entire backend state 
   * @param _fee Fee for processing epoch by node 
   * TODO: This function will have to be allowed to call by nodes 
   * running our decentralized network. Something similar to chainlink 
   * onlyAuthorized node 
   * Also, maybe not safe to pass the fee here with this next implementation
   */
  function updateEpoch(
    bytes32 _withdrawalsRoot, 
    bytes32 _exitsRoot,
    bytes32 _stateRoot,
    uint _fee
  ) external onlyOwner {
    withdrawalsRoot = _withdrawalsRoot;
    exitsRoot = _exitsRoot;
    stateRoot = _stateRoot;
    _transfer(owner(), _fee);
    emit Epoch(epoch++, _withdrawalsRoot, _exitsRoot, _stateRoot);
  }

  /// @dev Utility to transfer funds
  function _transfer(address recipient, uint amount) private {
    require(amount > 0, "Account balance is 0");
    (bool sent, ) = payable(recipient).call{value: amount, gas: 2300}("");
    require(sent, "Failed to send Ether");
  }

  receive () external payable {
  }
}
