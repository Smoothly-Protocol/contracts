// SPDX-License-Identifier: Apache-2.0
// Copyright 2022-2023 Smoothly Protocol LLC
pragma solidity 0.8.19;

// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable.sol)

// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// Copyright 2022-2023 Smoothly Protocol LLC

// OpenZeppelin Contracts (last updated v4.9.2) (utils/cryptography/MerkleProof.sol)

/**
 * @dev These functions deal with verification of Merkle Tree proofs.
 *
 * The tree and the proofs can be generated using our
 * https://github.com/OpenZeppelin/merkle-tree[JavaScript library].
 * You will find a quickstart guide in the readme.
 *
 * WARNING: You should avoid using leaf values that are 64 bytes long prior to
 * hashing, or use a hash function other than keccak256 for hashing leaves.
 * This is because the concatenation of a sorted pair of internal nodes in
 * the merkle tree could be reinterpreted as a leaf value.
 * OpenZeppelin's JavaScript library generates merkle trees that are safe
 * against this attack out of the box.
 */
library MerkleProof {
    /**
     * @dev Returns true if a `leaf` can be proved to be a part of a Merkle tree
     * defined by `root`. For this, a `proof` must be provided, containing
     * sibling hashes on the branch from the leaf to the root of the tree. Each
     * pair of leaves and each pair of pre-images are assumed to be sorted.
     */
    function verify(bytes32[] memory proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
        return processProof(proof, leaf) == root;
    }

    /**
     * @dev Calldata version of {verify}
     *
     * _Available since v4.7._
     */
    function verifyCalldata(bytes32[] calldata proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
        return processProofCalldata(proof, leaf) == root;
    }

    /**
     * @dev Returns the rebuilt hash obtained by traversing a Merkle tree up
     * from `leaf` using `proof`. A `proof` is valid if and only if the rebuilt
     * hash matches the root of the tree. When processing the proof, the pairs
     * of leafs & pre-images are assumed to be sorted.
     *
     * _Available since v4.4._
     */
    function processProof(bytes32[] memory proof, bytes32 leaf) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            computedHash = _hashPair(computedHash, proof[i]);
        }
        return computedHash;
    }

    /**
     * @dev Calldata version of {processProof}
     *
     * _Available since v4.7._
     */
    function processProofCalldata(bytes32[] calldata proof, bytes32 leaf) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            computedHash = _hashPair(computedHash, proof[i]);
        }
        return computedHash;
    }

    /**
     * @dev Returns true if the `leaves` can be simultaneously proven to be a part of a merkle tree defined by
     * `root`, according to `proof` and `proofFlags` as described in {processMultiProof}.
     *
     * CAUTION: Not all merkle trees admit multiproofs. See {processMultiProof} for details.
     *
     * _Available since v4.7._
     */
    function multiProofVerify(
        bytes32[] memory proof,
        bool[] memory proofFlags,
        bytes32 root,
        bytes32[] memory leaves
    ) internal pure returns (bool) {
        return processMultiProof(proof, proofFlags, leaves) == root;
    }

    /**
     * @dev Calldata version of {multiProofVerify}
     *
     * CAUTION: Not all merkle trees admit multiproofs. See {processMultiProof} for details.
     *
     * _Available since v4.7._
     */
    function multiProofVerifyCalldata(
        bytes32[] calldata proof,
        bool[] calldata proofFlags,
        bytes32 root,
        bytes32[] memory leaves
    ) internal pure returns (bool) {
        return processMultiProofCalldata(proof, proofFlags, leaves) == root;
    }

    /**
     * @dev Returns the root of a tree reconstructed from `leaves` and sibling nodes in `proof`. The reconstruction
     * proceeds by incrementally reconstructing all inner nodes by combining a leaf/inner node with either another
     * leaf/inner node or a proof sibling node, depending on whether each `proofFlags` item is true or false
     * respectively.
     *
     * CAUTION: Not all merkle trees admit multiproofs. To use multiproofs, it is sufficient to ensure that: 1) the tree
     * is complete (but not necessarily perfect), 2) the leaves to be proven are in the opposite order they are in the
     * tree (i.e., as seen from right to left starting at the deepest layer and continuing at the next layer).
     *
     * _Available since v4.7._
     */
    function processMultiProof(
        bytes32[] memory proof,
        bool[] memory proofFlags,
        bytes32[] memory leaves
    ) internal pure returns (bytes32 merkleRoot) {
        // This function rebuilds the root hash by traversing the tree up from the leaves. The root is rebuilt by
        // consuming and producing values on a queue. The queue starts with the `leaves` array, then goes onto the
        // `hashes` array. At the end of the process, the last hash in the `hashes` array should contain the root of
        // the merkle tree.
        uint256 leavesLen = leaves.length;
        uint256 proofLen = proof.length;
        uint256 totalHashes = proofFlags.length;

        // Check proof validity.
        require(leavesLen + proofLen - 1 == totalHashes, "MerkleProof: invalid multiproof");

        // The xxxPos values are "pointers" to the next value to consume in each array. All accesses are done using
        // `xxx[xxxPos++]`, which return the current value and increment the pointer, thus mimicking a queue's "pop".
        bytes32[] memory hashes = new bytes32[](totalHashes);
        uint256 leafPos = 0;
        uint256 hashPos = 0;
        uint256 proofPos = 0;
        // At each step, we compute the next hash using two values:
        // - a value from the "main queue". If not all leaves have been consumed, we get the next leaf, otherwise we
        //   get the next hash.
        // - depending on the flag, either another value from the "main queue" (merging branches) or an element from the
        //   `proof` array.
        for (uint256 i = 0; i < totalHashes; i++) {
            bytes32 a = leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++];
            bytes32 b = proofFlags[i]
                ? (leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++])
                : proof[proofPos++];
            hashes[i] = _hashPair(a, b);
        }

        if (totalHashes > 0) {
            require(proofPos == proofLen, "MerkleProof: invalid multiproof");
            unchecked {
                return hashes[totalHashes - 1];
            }
        } else if (leavesLen > 0) {
            return leaves[0];
        } else {
            return proof[0];
        }
    }

    /**
     * @dev Calldata version of {processMultiProof}.
     *
     * CAUTION: Not all merkle trees admit multiproofs. See {processMultiProof} for details.
     *
     * _Available since v4.7._
     */
    function processMultiProofCalldata(
        bytes32[] calldata proof,
        bool[] calldata proofFlags,
        bytes32[] memory leaves
    ) internal pure returns (bytes32 merkleRoot) {
        // This function rebuilds the root hash by traversing the tree up from the leaves. The root is rebuilt by
        // consuming and producing values on a queue. The queue starts with the `leaves` array, then goes onto the
        // `hashes` array. At the end of the process, the last hash in the `hashes` array should contain the root of
        // the merkle tree.
        uint256 leavesLen = leaves.length;
        uint256 proofLen = proof.length;
        uint256 totalHashes = proofFlags.length;

        // Check proof validity.
        require(leavesLen + proofLen - 1 == totalHashes, "MerkleProof: invalid multiproof");

        // The xxxPos values are "pointers" to the next value to consume in each array. All accesses are done using
        // `xxx[xxxPos++]`, which return the current value and increment the pointer, thus mimicking a queue's "pop".
        bytes32[] memory hashes = new bytes32[](totalHashes);
        uint256 leafPos = 0;
        uint256 hashPos = 0;
        uint256 proofPos = 0;
        // At each step, we compute the next hash using two values:
        // - a value from the "main queue". If not all leaves have been consumed, we get the next leaf, otherwise we
        //   get the next hash.
        // - depending on the flag, either another value from the "main queue" (merging branches) or an element from the
        //   `proof` array.
        for (uint256 i = 0; i < totalHashes; i++) {
            bytes32 a = leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++];
            bytes32 b = proofFlags[i]
                ? (leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++])
                : proof[proofPos++];
            hashes[i] = _hashPair(a, b);
        }

        if (totalHashes > 0) {
            require(proofPos == proofLen, "MerkleProof: invalid multiproof");
            unchecked {
                return hashes[totalHashes - 1];
            }
        } else if (leavesLen > 0) {
            return leaves[0];
        } else {
            return proof[0];
        }
    }

    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? _efficientHash(a, b) : _efficientHash(b, a);
    }

    function _efficientHash(bytes32 a, bytes32 b) private pure returns (bytes32 value) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }
}

/// @title Smoothing Pool V2 Contract.
/// @notice This contract receives and distributes all the rewards from registered
/// validators evenly and smoothly.
contract SmoothlyPool is Ownable {
    uint64 internal constant STAKE_FEE = 0.05 ether;
    uint64 internal constant MAX_ADD_FEE = 0.015 ether;
    uint64 public epoch;
    bytes32 public withdrawalsRoot;
    bytes32 public exitsRoot;
    /// @dev Empty root hash with no values in it
    bytes32 public stateRoot =
        hex"56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421";

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
    /// @param indexes Validator indexes
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
    /// @param indexes Validator indexes
    /// @param stake Amount of stake of all validators associated to an eth1 
    /// address that requested exit on previous epochs
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
    /// @dev Front-end needs to check for a valid validator call and a valid
    /// amount, otherwise funds will get lost and added as rewards for 
    /// registrants of the pool
    function addStake(uint64 index) external payable {
        if (msg.value == 0) revert ZeroAmount();
        if (msg.value > MAX_ADD_FEE) revert AmountTooBig();
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
        ++epoch;
        if (_fee > 0) _transfer(msg.sender, _fee);
        emit Epoch(epoch, _stateRoot, _fee);
    }

    /// @dev Utility to transfer funds
    /// @param recipient address of recipient
    /// @param amount amount being transferred
    function _transfer(address recipient, uint256 amount) private {
        if (amount == 0) revert ZeroAmount();
        (bool sent, ) = recipient.call{value: amount}("");
        if (!sent) revert CallTransferFailed();
    }
}

/// @title Smoothing Pool Governance Contract
/// @notice This contract is in charge of receiving votes from operator
/// nodes with the respective withdrawals, exits and state root hashes of the
/// computed state for every epoch. Reach consensus and pass the data to the
/// SmoothlyPool contract.
contract PoolGovernance is Ownable {
    uint8 internal constant votingRatio = 66; // % of agreements required
    uint32 public epochInterval = 5 days;
    uint64 public epochNumber;
    uint64 public lastEpoch;
    address[] public operators;
    SmoothlyPool public pool;

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
    error NotEnoughOperators();

    /// @dev restrict calls only to operators
    modifier onlyOperator() {
        if (!isOperator[msg.sender]) revert Unauthorized();
        _;
    }

    constructor(address[] memory _operators, SmoothlyPool _pool) {
        lastEpoch = uint64(block.timestamp);
        address(_pool) == address(0)
          ? pool = new SmoothlyPool() 
          : pool = SmoothlyPool(_pool);
        _addOperators(_operators);
    }

    /// @dev Receives fees from Smoothly Pool
    receive() external payable {
        if (msg.sender != address(pool)) revert Unauthorized();
    }

    /// @notice Gets all active operators
    /// @return All active operators
    function getOperators() external view returns (address[] memory) {
        return operators;
    }

    /// @notice withdraws accumulated rewards from an operator
    function withdrawRewards() external onlyOperator {
        uint256 rewards = operatorRewards[msg.sender];
        operatorRewards[msg.sender] = 0;

        if (rewards == 0) revert ZeroAmount();
        (bool sent, ) = msg.sender.call{value: rewards}("");
        if (!sent) revert CallTransferFailed();
    }

    /// @notice Proposal Data for current epoch computed from every operator
    /// @dev operators need to reach an agreement of at least votingRatio
    /// and no penalties are added for bad proposals or no proposals as admin
    /// have the abilities to delete malicious operators
    /// @param epoch Data needed to update Smoothly Pool state
    function proposeEpoch(Epoch calldata epoch) external onlyOperator {
        if (block.timestamp < lastEpoch + epochInterval)
            revert EpochTimelockNotReached();

        bytes32 vote = keccak256(abi.encode(epoch));
        bytes32 prevVote = votes[epochNumber][msg.sender];
        uint256 operatorsLen = operators.length;

        if(operatorsLen == 1) revert NotEnoughOperators();

        votes[epochNumber][msg.sender] = vote;

        if (prevVote != bytes32(0)) --voteCounter[epochNumber][prevVote];

        uint256 count = ++voteCounter[epochNumber][vote];
        if (((count * 100) / operatorsLen) >= votingRatio) {
            pool.updateEpoch(
                epoch.withdrawals,
                epoch.exits,
                epoch.state,
                epoch.fee
            );

            uint256 operatorShare = epoch.fee / operatorsLen;
            address[] memory _operators = operators;
            for (uint256 i = 0; i < operatorsLen; ++i) {
                operatorRewards[_operators[i]] += operatorShare;
            }

            ++epochNumber;
            lastEpoch = uint64(block.timestamp);
        }
    }

    /// @notice Adds operators
    /// @param _operators List of new operators
    function addOperators(address[] calldata _operators) external onlyOwner {
        _addOperators(_operators); 
    }

    /// @notice Deletes operators
    /// @param _operators List of operators to be removed
    function deleteOperators(address[] calldata _operators) external onlyOwner {
        for (uint256 i = 0; i < _operators.length; ++i) {
            isOperator[_operators[i]] = false;
            uint256 operatorsLen = operators.length;
            for (uint256 x = 0; x < operatorsLen; ++x) {
                if (operators[x] == _operators[i]) {
                    operators[x] = operators[operatorsLen - 1];
                    operators.pop();
                    // Transfer rewards to pool
                    uint256 rewards = operatorRewards[_operators[i]];
                    operatorRewards[_operators[i]] = 0;
                    if (rewards != 0) {
                      (bool sent, ) = address(pool).call{value: rewards}("");
                      if (!sent) revert CallTransferFailed();
                    }
                    break;
                }
            }
        }
    }

    /// @notice Transfers Ownership of Smoothly Pool
    /// @param newOwner owner to transfer ownership to
    function transferPoolOwnership(address newOwner) external onlyOwner {
        pool.transferOwnership(newOwner);
    }

    /// @notice Changes epochInterval timelock value
    /// @param interval updates epochInterval
    function updateInterval(uint32 interval) external onlyOwner {
      epochInterval = interval;
    }

    /// @notice Adds operators
    /// @param _operators List of new operators
    function _addOperators(address[] memory _operators) internal {
        for (uint256 i = 0; i < _operators.length; ++i) {
            if (isOperator[_operators[i]])
                revert ExistingOperator(_operators[i]);
            isOperator[_operators[i]] = true;
            operators.push(_operators[i]);
        }
    }
}
