// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.16;

/**
 * @title Smoothing Pool Governance Contract.
 * @notice This contract is in charged of recieving votes from smoothly validator 
 * nodes with the respective withdrawals, exits and state root hashes of the 
 * computed state for every epoch. Reach consensus and pass the data to the
 * SmoothlyPool contract.
 */

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

  struct Epoch {
    bytes32 withdrawals;
    bytes32 exits; 
    bytes32 state;
    uint fee;
  }

  mapping(address => bool) public isOperator;
  mapping(address => uint) public operatorRewards;
  mapping(uint => mapping(address => Epoch)) public votes;

  error ExistingOperator(address operator);
  error Unauthorized();
  error EpochTimelockNotReached();

  modifier onlyOperator {
    if(!isOperator[msg.sender]) revert Unauthorized();
    _;
  }

  modifier onlyPool {
    if(msg.sender != address(pool)) revert Unauthorized();
    _;
  }

  constructor(address payable _pool) {
    lastEpoch = block.timestamp;
    pool = SmoothlyPoolV2(_pool);
  }

  receive () onlyPool external payable {
  }

  function getRewards(address operator) public view returns(uint) {
    return operatorRewards[operator];
  }

  function getOperators() external view returns(address[] memory) {
    return operators;
  }

  function withdrawRewards() onlyOperator external {
    address operator = msg.sender;
    uint rewards = getRewards(operator);
    operatorRewards[operator] = 0;
    _transfer(operator, rewards);
  }

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
        // Call smoothly pool make sure it doesn't revert
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

  function addOperators(address[] memory _operators) onlyOwner external {
    for (uint i = 0; i < _operators.length; i++){
      if(isOperator[_operators[i]]) revert ExistingOperator(_operators[i]);
        isOperator[_operators[i]] = true;
        operators.push(_operators[i]);
    }
  }

  function deleteOperators(address[] memory _operators) onlyOwner external {
    for (uint i = 0; i < _operators.length; i++){
      isOperator[_operators[i]] = false;
      _remove(_operators[i]);
    }
  }

  function _computeAgreements(uint count) private view returns(uint) {
    return (count * 100) / operators.length; 
  }

  function _isVoteEqual(Epoch memory vote1, Epoch memory vote2) private pure returns(bool) {
    if(keccak256(abi.encode(vote1)) == keccak256(abi.encode(vote2))){
      return true;
    }
    return false;
  }

  function _distributeRewards(uint fee, address[] memory _operators) private {
    uint operatorShare = fee / _operators.length;
    for(uint i = 0; i < _operators.length; i++) {
      operatorRewards[_operators[i]] += operatorShare;    
    } 
  }

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
  function _transfer(address recipient, uint amount) private {
    require(amount > 0, "Account balance is 0");
    (bool sent, ) = payable(recipient).call{value: amount, gas: 2300}("");
    require(sent, "Failed to send Ether");
  }
}
