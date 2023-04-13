// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.16;

/// @title Smoothing Pool Governance Contract
/// @notice This contract is in charge of recieving votes from operator 
/// nodes with the respective withdrawals, exits and state root hashes of the 
/// computed state for every epoch. Reach consensus and pass the data to the
/// SmoothlyPool contract.

import "@openzeppelin/contracts/access/Ownable.sol";
import './SmoothlyPoolV2.sol';
import "hardhat/console.sol";

contract PoolGovernance is Ownable {
  uint constant public epochInterval = 1 weeks;
  uint constant public votingRatio = 66; // % of agreements required
  uint public epochNumber = 0;
  uint public lastEpoch;
  address[] public operators;
  SmoothlyPoolV2 immutable pool;

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
    pool = SmoothlyPoolV2(_pool);
  }

  /// @dev Recieves fees from Smoothly Pool
  receive () onlyPool external payable {
  }

  /// @notice Gets all active operators 
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
    uint count = 0;
    address[] memory _operators = operators;
    for(uint i = 0; i < _operators.length; i++) {
      Epoch memory vote = votes[epochNumber][_operators[i]];
      if(_isVoteEqual(vote, epoch)) {
        count += 1;
      }
      if(_computeAgreements(count) >= votingRatio) {
        pool.updateEpoch(
          epoch.withdrawals,
          epoch.exits,
          epoch.state,
          epoch.fee 
        );
        _distributeRewards(epoch.fee, _operators);
        epochNumber++;       
        lastEpoch = block.timestamp;
        break;
      }
    }
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

  /// @notice Gets cumulative rewards from a single operator
  /// @param operator address of operator 
  function getRewards(address operator) public view returns(uint) {
    return operatorRewards[operator];
  }

  /// @dev Computes votingRatio
  /// @param count agreements of all operator up to date 
  function _computeAgreements(uint count) private view returns(uint) {
    return (count * 100) / operators.length; 
  }

  /// @dev Compare to votes 
  /// @param vote1 Epoch data of other operator 
  /// @param vote2 Epoch data of caller 
  function _isVoteEqual(Epoch memory vote1, Epoch memory vote2) private pure returns(bool) {
    if(keccak256(abi.encode(vote1)) == keccak256(abi.encode(vote2))){
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
