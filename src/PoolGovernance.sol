// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.16;

/**
 * @title Smoothing Pool Governance Contract.
 * @notice This contract is in charged of recieving votes from smoothly validator 
 * nodes with the respective withdrawals, exits and state root hashes of the 
 * computed state for every epoch. Reach consensus and pass the data to the
 * SmoothlyPool contract.
 */

import "openzeppelin-contracts/access/Ownable.sol";
import './SmoothlyPoolV2.sol';

contract PoolGovernance is Ownable {
  uint public immutable epochInterval;
  uint public immutable votingRatio; // percentage of agreements required
  uint public epochNumber;
  uint public lastEpoch;
  address[] public validators;
  SmoothlyPoolV2 immutable pool;

  struct Epoch {
    bytes32 withdrawals;
    bytes32 exits; 
    bytes32 state;
    uint fee;
  }

  mapping(address => bool) public isValidator;
  mapping(uint => mapping(address => Epoch)) public votes;

  error Unauthorized();
  error EpochTooEarly();

  constructor(uint initTimestamp, address payable _pool) {
    epochNumber = 0;
    votingRatio = 66;
    lastEpoch = initTimestamp;
    epochInterval = 1 weeks;
    pool = SmoothlyPoolV2(_pool);
  }

  modifier onlyValidator {
    if(!isValidator[msg.sender]) revert Unauthorized();
    _;
  }

  receive () external payable {
  }

  function proposeEpoch(Epoch memory epoch) onlyValidator external {
    if(block.timestamp < (lastEpoch + epochInterval)) revert EpochTooEarly();
    votes[epochNumber][msg.sender] = epoch;
    uint count = 0;
    for(uint i = 0; i < validators.length; i++) {
      Epoch memory vote = votes[epochNumber][validators[i]];
      if(_isVoteEqual(vote, epoch)) {
        count += 1;
      }
      if(_computeAgreements(count) >= votingRatio) {
        // Call smoothly pool make sure it doesn't revert
        epochNumber++;       
        lastEpoch = block.timestamp;
        break;
      }
    }
  }

  function addValidator() onlyOwner external {
    isValidator[msg.sender] = true;
    validators.push(msg.sender);
  }

  function _computeAgreements(uint count) internal view returns(uint) {
    return (count * 100) / validators.length; 
  }

  function _isVoteEqual(Epoch memory vote1, Epoch memory vote2) internal pure returns(bool) {
    if(keccak256(abi.encode(vote1)) == keccak256(abi.encode(vote2))){
      return true;
    }
    return false;
  }

}
