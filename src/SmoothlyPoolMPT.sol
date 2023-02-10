// SPDX-License-Identifier: UNLICENSED 
pragma solidity ^0.8.16;

import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/security/ReentrancyGuard.sol";
import "Solidity-RLP/RLPReader.sol";
import "./MPTVerifier.sol";

contract SmoothlyPoolMPT is MPTVerifier, Ownable, ReentrancyGuard {
  using RLPReader for RLPReader.RLPItem;
  using RLPReader for bytes;

	uint constant STAKE_FEE = 0.65 ether;

	uint public totalStake;
  bytes32 ROOT = hex'56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421'; // Empty

  struct ProofData {
    bytes[] proof;
    bytes expectedValue; 
  }

	event ValidatorRegistered(address indexed eth1_addr, string validator);
	event ValidatorDeactivated(string validator);
	event Withdrawal(string indexed pubKey, uint256 value);
  event Rebalance(uint tRewards, uint tUsersRewarded, uint tSlashMiss, uint tSlashFee);

	function registerBulk(bytes[] memory pubKeys) external payable {
		require(msg.value == (STAKE_FEE * pubKeys.length), "not enough eth send");
		for(uint i; i < pubKeys.length; i++) {
			register(pubKeys[i]);
		}	
	}

	function register(bytes memory pubKey) internal {
		require(pubKey.length == 98, "pubKey with wrong format");
		require(pubKey[0] == "0", "make sure it uses 0x");
		require(pubKey[1] == "x", "make sure it uses 0x");
		totalStake += STAKE_FEE;
		emit ValidatorRegistered(msg.sender, string(pubKey));
	}

	function withdrawRewards(ProofData memory data) nonReentrant external {
    MerkleProof memory proof = MerkleProof(
      ROOT,
      abi.encodePacked(keccak256(abi.encode(msg.sender))), 
      data.proof,
      0, 
      0, 
      data.expectedValue
    );
    require(verifyProof(proof), "Validator not registered");
    RLPReader.RLPItem[] memory validators = data.expectedValue.toRlpItem().toList();
    /*
			require(v[id].rewards > 0, "Validator reward balance is 0");
      require(v[id].active, "Validator not active");
			totalRewards -= v[id].rewards;
			validators[msg.sender][id].rewards = 0;
			val += v[id].rewards;
      emit Withdrawal(string(v[id].pubKey), v[id].rewards);
		}
		(bool sent, ) = payable(msg.sender).call{value: val, gas: 2300}("");
		require(sent, "Failed to send Ether");
   */
	}

  function setROOT(bytes32 _root) external {
    ROOT = _root;
  }

	receive () external payable {
	}
}
