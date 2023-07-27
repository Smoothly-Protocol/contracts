// Copyright 2022-2023 Smoothly Protocol LLC
// SPDX License identifier: Apache-2.0
pragma solidity ^0.8.16;

/// @title Smoothing Pool Governance Contract
/// @notice This contract is in charge of recieving votes from operator 
/// nodes with the respective withdrawals, exits and state root hashes of the 
/// computed state for every epoch. Reach consensus and pass the data to the
/// SmoothlyPool contract.

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ISmoothlyPoolV2} from './interfaces/ISmoothlyPoolV2.sol';

contract PoolGovernanceV2 is Ownable {
  uint constant public epochInterval = 1 days;
  uint constant public votingRatio = 66; // % of agreements required
  uint public epochNumber;
  uint public lastEpoch;
  uint public voteCounter;
  address[] public operators;
  ISmoothlyPoolV2 immutable pool;

  /// @notice Epoch data to update the Smoothly Pool state
  /// @param withdrwals Merkle root hash for withdrawals
  /// @param exits Merkle root hash for exits 
  /// @param state MPT root hash of entire state 
  /// @param fee distributed to operators to keep network alive 
  struct Epoch {
    bytes32 withdrawals;
    bytes32 exits; 
    bytes32 state;
    uint fee;
  }

  /// @dev checks if operator is active 
  mapping(address => bool) public isOperator;
  /// @dev records operator accumulative rewards 
  mapping(address => uint) public operatorRewards;
  /// @dev records operator votes for each epochNumber
  mapping(uint => mapping(address => Epoch)) public votes;

  error ExistingOperator(address operator);
  error Unauthorized();
  error EpochTimelockNotReached();

  /// @dev restrict calls only to operators
  modifier onlyOperator {
    if(!isOperator[msg.sender]) revert Unauthorized();
    _;
  }

  /// @dev restrict calls only to Smoothly Pool
  modifier onlyPool {
    if(msg.sender != address(pool)) revert Unauthorized();
    _;
  }

  constructor(address payable _pool) {
    lastEpoch = block.timestamp;
    pool = ISmoothlyPoolV2(_pool);
  }

  /// @dev Recieves fees from Smoothly Pool
  receive () onlyPool external payable {
  }

  /// @notice Gets all active operators 
  /// @return All active operators
  function getOperators() external view returns(address[] memory) {
    return operators;
  }

  /// @notice withdraws accumulated rewards from an operator
  function withdrawRewards() onlyOperator external {
    address operator = msg.sender;
    uint rewards = getRewards(operator);
    operatorRewards[operator] = 0;
    _transfer(operator, rewards);
  }

  /// @notice Proposal Data for current epoch computed from every operator
  /// @dev operators need to reach an agreement of at least votingRatio
  /// and no penalties are added for bad proposals or no proposals as admin
  /// have the abilities to delete malicious operators
  /// @param epoch Data needed to update Smoothly Pool state
  function proposeEpoch(Epoch memory epoch) onlyOperator external {
    if(block.timestamp < (lastEpoch + epochInterval)) revert EpochTimelockNotReached();
    votes[epochNumber][msg.sender] = epoch;
    voteCounter++;

    address[] memory _operators = operators;

    if(voteCounter >= _operators.length) _computeEpoch(_operators);
  }

  /// @notice Adds operators
  /// @param _operators List of new operators
  function addOperators(address[] memory _operators) onlyOwner external {
    for (uint i = 0; i < _operators.length; i++){
      if(isOperator[_operators[i]]) revert ExistingOperator(_operators[i]);
      isOperator[_operators[i]] = true;
      operators.push(_operators[i]);
    }
  }

  /// @notice Deletes operators
  /// @param _operators List of operators to be removed
  function deleteOperators(address[] memory _operators) onlyOwner external {
    for (uint i = 0; i < _operators.length; i++){
      isOperator[_operators[i]] = false;
      _remove(_operators[i]);
    }
  }

  /// @notice Transfers Ownership of Smoothly Pool
  /// @dev used in case we need to upgrade this contract
  /// @param newOwner owner to transfer ownership to 
  function transferPoolOwnership(address newOwner) onlyOwner external {
    pool.transferOwnership(newOwner);
  }

  /// @notice Gets cumulative rewards from a single operator
  /// @param operator address of operator 
  function getRewards(address operator) public view returns(uint) {
    return operatorRewards[operator];
  }

  /// @dev Finds majority vote using Boyer-Moore Majority Algorithm
  /// @param _operators List of all operators
  function _computeEpoch(address[] memory _operators) private {
    uint count = 0;
    Epoch[] memory _votes = _getVotes(_operators);
    Epoch memory candidate;

    // Find majority candidate
    for(uint i = 0; i < _operators.length; i++) {
      if(count == 0) {
        candidate = _votes[i];
        count = 1;
      } else if(_isVoteEqual(_votes[i], candidate)) {
        count++;
      } else {
        count--;
      } 
    }

    // Check if majority candidate requires votingRatio
    count = 0;
    for(uint i = 0; i < _operators.length; i++) {
      if(_isVoteEqual(_votes[i], candidate)) {
        count++;
      }
    }

    if(_computeAgreements(count) >= votingRatio) {
      pool.updateEpoch(
        candidate.withdrawals,
        candidate.exits,
        candidate.state,
        candidate.fee 
      );
      _distributeRewards(candidate.fee, _operators);
      epochNumber++;       
      lastEpoch = block.timestamp;
      voteCounter = 0;
    }
  }

  /// @dev Gets all votes from current epoch to save on sloads
  /// @param _operators List of new operators
  /// @return _votes List of current operator votes
  function _getVotes(address[] memory _operators) private view returns(Epoch[] memory _votes) {
    _votes = new Epoch[] (_operators.length);
    for(uint i = 0; i < _operators.length;) {
      _votes[i] = votes[epochNumber][_operators[i]];
      unchecked {
        ++i;
      }
    }
  }

  /// @dev Computes votingRatio
  /// @param count agreements of all operator up to date 
  /// @return current epoch votingRatio
  function _computeAgreements(uint count) private view returns(uint) {
    return (count * 100) / operators.length; 
  }

  /// @dev Compare to votes and avoids empty ones
  /// @param vote1 Epoch data of other operator 
  /// @param vote2 Epoch data of caller 
  /// @return equality in boolean
  function _isVoteEqual(Epoch memory vote1, Epoch memory vote2) private pure returns(bool) {
    if(
      vote1.state == 0 &&
      vote1.withdrawals == 0 &&
      vote1.exits == 0
    ) {
      return false;
    } else if(keccak256(abi.encode(vote1)) == keccak256(abi.encode(vote2))){
      return true;
    }
    return false;
  }

  /// @dev Distributes rewards equally for all active operators 
  /// @param fee coming from Smoothly Pool for operators
  /// @param _operators active 
  function _distributeRewards(uint fee, address[] memory _operators) private {
    uint operatorShare = fee / _operators.length;
    for(uint i = 0; i < _operators.length; i++) {
      operatorRewards[_operators[i]] += operatorShare;    
    } 
  }

  /// @dev Utility to remove an operator from operators array without 
  /// empty space
  /// @param operator address of operator 
  function _remove(address operator) private {
    address[] memory _operators = operators;
    for (uint i = 0; i < _operators.length; i++){
      if(_operators[i] == operator) {
        operators[i] = _operators[_operators.length - 1];   
        operators.pop(); 
        break;
      }
    }
  }

  /// @dev Utility to transfer funds
  /// @param recipient address of recipient
  /// @param amount amount being transfered 
  function _transfer(address recipient, uint amount) private {
    require(amount > 0, "Account balance is 0");
    (bool sent, ) = payable(recipient).call{value: amount, gas: 2300}("");
    require(sent, "Failed to send Ether");
  }
}
