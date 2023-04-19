// Copyright 2022-2023 Smoothly Protocol LLC
// SPDX License identifier: Apache-2.0
pragma solidity ^0.8.16;

interface ISmoothlyPoolV2 {
  /// @notice Updates epoch number and Merkle root hashes 
  /// @param _withdrawalsRoot Merkle root hash for withdrawals
  /// @param _exitsRoot Merkle root hash for exits 
  /// @param _stateRoot Merkle Patricia Trie root hash for entire backend state 
  /// @param _fee Fee for processing epochs by operators
  function updateEpoch(
    bytes32 _withdrawalsRoot, 
    bytes32 _exitsRoot,
    bytes32 _stateRoot,
    uint _fee
  ) external;

  /// @dev Transfers ownership of the contract to a new account (`newOwner`).
  /// Can only be called by the current owner.
  function transferOwnership(address newOwner) external;
}
