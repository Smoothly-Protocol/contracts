// SPDX-License-Identifier: Apache-2.0
// Copyright 2022-2023 Smoothly Protocol LLC
pragma solidity 0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SmoothlyPool} from "./SmoothlyPool.sol";

/// @title Smoothing Pool Governance Contract
/// @notice This contract is in charge of receiving votes from operator
/// nodes with the respective withdrawals, exits and state root hashes of the
/// computed state for every epoch. Reach consensus and pass the data to the
/// SmoothlyPool contract.
contract PoolGovernance is Ownable {
    uint32 internal constant epochInterval = 1 days;
    uint8 internal constant votingRatio = 66; // % of agreements required
    uint64 public epochNumber;
    uint64 public lastEpoch;
    address[] public operators;
    SmoothlyPool public immutable pool;

    /// @notice Epoch data to update the Smoothly Pool state
    /// @param withdrawals Merkle root hash for withdrawals
    /// @param exits Merkle root hash for exits
    /// @param state MPT root hash of entire state
    /// @param fee distributed to operators to keep network alive
    struct Epoch {
        bytes32 withdrawals;
        bytes32 exits;
        bytes32 state;
        uint256 fee;
    }

    /// @dev checks if operator is active
    mapping(address => bool) public isOperator;
    /// @dev records operator accumulative rewards
    mapping(address => uint256) public operatorRewards;
    /// @dev records operator votes for each epochNumber
    mapping(uint256 => mapping(address => bytes32)) public votes;
    /// @dev counts number of votes for each epochNumber
    mapping(uint256 => mapping(bytes32 => uint256)) public voteCounter;

    error ExistingOperator(address operator);
    error Unauthorized();
    error EpochTimelockNotReached();
    error ZeroAmount();
    error CallTransferFailed();

    /// @dev restrict calls only to operators
    modifier onlyOperator() {
        if (!isOperator[msg.sender]) revert Unauthorized();
        _;
    }

    /// @dev restrict calls only to Smoothly Pool
    modifier onlyPool() {
        if (msg.sender != address(pool)) revert Unauthorized();
        _;
    }

    constructor() {
        lastEpoch = uint64(block.timestamp);
        pool = new SmoothlyPool();
    }

    /// @dev Receives fees from Smoothly Pool
    receive() external payable onlyPool {}

    /// @notice Gets all active operators
    /// @return All active operators
    function getOperators() external view returns (address[] memory) {
        return operators;
    }

    /// @notice withdraws accumulated rewards from an operator
    function withdrawRewards() external onlyOperator {
        uint256 rewards = operatorRewards[msg.sender];
        operatorRewards[msg.sender] = 0;
        _transfer(msg.sender, rewards);
    }

    /// @notice Proposal Data for current epoch computed from every operator
    /// @dev operators need to reach an agreement of at least votingRatio
    /// and no penalties are added for bad proposals or no proposals as admin
    /// have the abilities to delete malicious operators
    /// @param epoch Data needed to update Smoothly Pool state
    function proposeEpoch(Epoch calldata epoch) external onlyOperator {
        if (block.timestamp < lastEpoch + epochInterval) revert EpochTimelockNotReached();

        bytes32 vote = keccak256(abi.encode(epoch));
        bytes32 prevVote = votes[epochNumber][msg.sender];
        uint256 count = ++voteCounter[epochNumber][vote];
        votes[epochNumber][msg.sender] = vote;

        if (prevVote != bytes32(0)) --voteCounter[epochNumber][prevVote];

        if ((count * 100 / operators.length) >= votingRatio) {
            pool.updateEpoch(
                epoch.withdrawals,
                epoch.exits,
                epoch.state,
                epoch.fee
            );
            _distributeRewards(epoch.fee, operators);
            ++epochNumber;
            lastEpoch = uint64(block.timestamp);
        }
    }

    /// @notice Adds operators
    /// @param _operators List of new operators
    function addOperators(address[] calldata _operators) external onlyOwner {
        for (uint256 i = 0; i < _operators.length; ++i) {
            if (isOperator[_operators[i]])
                revert ExistingOperator(_operators[i]);
            isOperator[_operators[i]] = true;
            operators.push(_operators[i]);
        }
    }

    /// @notice Deletes operators
    /// @param _operators List of operators to be removed
    function deleteOperators(address[] calldata _operators) external onlyOwner {
        for (uint256 i = 0; i < _operators.length; ++i) {
            isOperator[_operators[i]] = false;
            _remove(_operators[i]);
        }
    }

    /// @notice Transfers Ownership of Smoothly Pool
    /// @param newOwner owner to transfer ownership to
    function transferPoolOwnership(address newOwner) external onlyOwner {
        pool.transferOwnership(newOwner);
    }

    /// @dev Distributes rewards equally for all active operators
    /// @param fee coming from Smoothly Pool for operators
    /// @param _operators active
    function _distributeRewards(
        uint256 fee,
        address[] memory _operators
    ) private {
        uint256 operatorShare = fee / _operators.length;
        for (uint256 i = 0; i < _operators.length; ++i) {
            operatorRewards[_operators[i]] += operatorShare;
        }
    }

    /// @dev Utility to remove an operator from operators array without
    /// empty space
    /// @param operator address of operator
    function _remove(address operator) private {
        uint256 operatorsLen = operators.length;
        for (uint256 i = 0; i < operatorsLen; ++i) {
            if (operators[i] == operator) {
                operators[i] = operators[operatorsLen - 1];
                operators.pop();
                break;
            }
        }
    }

    /// @dev Utility to transfer funds
    /// @param recipient address of recipient
    /// @param amount amount being transferred
    function _transfer(address recipient, uint256 amount) private {
        if (amount == 0) revert ZeroAmount();
        (bool sent, ) = recipient.call{value: amount, gas: 2300}("");
        if (!sent) revert CallTransferFailed();
    }
}
