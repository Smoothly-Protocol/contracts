// SPDX-License-Identifier: Apache-2.0
// Copyright 2022-2023 Smoothly Protocol LLC
pragma solidity 0.8.19;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title Smoothing Pool V2 Contract.
/// @notice This contract receives and distributes all the rewards from registered
/// validators evenly and smoothly.

contract SmoothlyPool is Ownable {
    uint64 internal constant STAKE_FEE = 0.065 ether;
    uint64 public epoch;
    bytes32 public withdrawalsRoot;
    bytes32 public exitsRoot;
    bytes32 public stateRoot =
        hex"56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421"; // Empty

    /// @dev Flags registrant on epoch to prevent double withdrawals
    mapping(address => mapping(uint64 => bool)) claimedWithdrawal;
    /// @dev Flags registrant on epoch to prevent double exits
    mapping(address => mapping(uint64 => bool)) claimedExit;

    event Registered(address indexed eth1, uint64[] indexes);
    event RewardsWithdrawal(
        address indexed eth1,
        uint64[] indexes,
        uint256 value
    );
    event StakeWithdrawal(
        address indexed eth1,
        uint64[] indexes,
        uint256 value
    );
    event StakeAdded(address indexed eth1, uint64 index, uint256 value);
    event ExitRequested(address indexed eth1, uint64[] indexes);
    event Epoch(uint64 indexed epoch, bytes32 stateRoot, uint256 fee);

    error NotEnoughEth();
    error IncorrectProof();
    error AlreadyClaimed();
    error ZeroAmount();
    error CallTransferFailed();
    error AmountTooBig();

    receive() external payable {}

    /// @notice Register n amount of validators to the pool
    /// @param indexes Validator indexes
    /// @dev Backend verifies ownership of the validators
    /// This is intended to be called from the front-end, double checking
    /// for ownership. Anyone registering unowned validators will lose their staking
    /// funds and those will be distributed amongst the pool registrants.
    function registerBulk(uint64[] calldata indexes) external payable {
        if (msg.value != (STAKE_FEE * indexes.length)) revert NotEnoughEth();
        emit Registered(msg.sender, indexes);
    }

    /// @notice Withdraw rewards from the pool
    /// @param proof Merkle Proof
    /// @param rewards All rewards accumulated from all validators associated
    /// to an eth1 address
    function withdrawRewards(
        bytes32[] calldata proof,
        uint64[] calldata indexes,
        uint256 rewards
    ) external {
        if (
            !MerkleProof.verify(
                proof,
                withdrawalsRoot,
                keccak256(
                    bytes.concat(
                        keccak256(abi.encode(msg.sender, indexes, rewards))
                    )
                )
            )
        ) revert IncorrectProof();
        if (claimedWithdrawal[msg.sender][epoch]) revert AlreadyClaimed();
        claimedWithdrawal[msg.sender][epoch] = true;
        _transfer(msg.sender, rewards);
        emit RewardsWithdrawal(msg.sender, indexes, rewards);
    }

    /// @notice Withdraws stake on exit request
    /// @param proof Merkle Proof
    /// @param stake Amount of stake of all validators that requested exit on
    /// previous epochs
    /// @dev Registrants that don't request an exit of their validators
    /// won't be included
    function withdrawStake(
        bytes32[] calldata proof,
        uint64[] calldata indexes,
        uint256 stake
    ) external {
        if (
            !MerkleProof.verify(
                proof,
                exitsRoot,
                keccak256(
                    bytes.concat(
                        keccak256(abi.encode(msg.sender, indexes, stake))
                    )
                )
            )
        ) revert IncorrectProof();
        if (claimedExit[msg.sender][epoch]) revert AlreadyClaimed();

        claimedExit[msg.sender][epoch] = true;
        _transfer(msg.sender, stake);
        emit StakeWithdrawal(msg.sender, indexes, stake);
    }

    /// @notice Allows user to exit pool retrieving stake in next epoch
    /// @param indexes Validator indexes
    function requestExit(uint64[] calldata indexes) external {
        emit ExitRequested(msg.sender, indexes);
    }

    /// @notice Adds stake to a validator in the pool
    /// @param index Validator index
    /// @dev Front-end needs to check for a valid validator call, otherwise funds
    /// will get lost and added as rewards for registrants of the pool
    function addStake(uint64 index) external payable {
        if (msg.value == 0) revert ZeroAmount();
        if (msg.value > STAKE_FEE) revert AmountTooBig();
        emit StakeAdded(msg.sender, index, msg.value);
    }

    /// @notice Updates epoch number and Merkle root hashes
    /// @param _withdrawalsRoot Merkle root hash for withdrawals
    /// @param _exitsRoot Merkle root hash for exits
    /// @param _stateRoot Merkle Patricia Trie root hash for entire backend state
    /// @param _fee Fee for processing epochs by operators
    function updateEpoch(
        bytes32 _withdrawalsRoot,
        bytes32 _exitsRoot,
        bytes32 _stateRoot,
        uint256 _fee
    ) external onlyOwner {
        withdrawalsRoot = _withdrawalsRoot;
        exitsRoot = _exitsRoot;
        stateRoot = _stateRoot;
        _transfer(owner(), _fee);
        ++epoch;
        emit Epoch(epoch, _stateRoot, _fee);
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
