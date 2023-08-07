// SPDX-License-Identifier: Apache-2.0
// Copyright 2022-2023 Smoothly Protocol LLC
pragma solidity 0.8.19;

interface ISmoothlyPool {
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
  ) external;

  /// @dev Transfers ownership of the contract to a new account (`newOwner`).
  /// Used to update PoolGovernance contract.
  /// @param newOwner owner to transfer ownership to.
  function transferOwnership(address newOwner) external;
}
