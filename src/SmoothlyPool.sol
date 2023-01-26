// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/security/ReentrancyGuard.sol";

contract SmoothlyPool is Ownable, ReentrancyGuard {
	uint constant STAKE_FEE = 0.65 ether;
	uint constant SLASH_MISS = 0.15 ether;
	uint constant SLASH_FEE = 0.5 ether;

	uint public totalStake;
	uint public totalRewards;
	uint public totalFees;
	
	struct Validator {
		bytes pubKey;
		uint rewards;
		uint slash_miss;
		uint slash_fee;
		uint stake;
    bool active;
	}

	struct RebalanceUser {
		address eth1Addr;
		uint id;
		uint rewards;
		uint slash_miss;
		uint slash_fee;
    bool active;
	}

	mapping(address => Validator[]) validators;

	event ValidatorRegistered(address indexed eth1_addr, string validator, uint id);
	event ValidatorDeactivated(string validator);
	event Withdrawal(string indexed pubKey, uint256 value);
  event Rebalance(uint tRewards, uint tUsersRewarded, uint tSlashMiss, uint tSlashFee);

	function registerBulk(bytes[] memory pubKeys) external payable {
		require(msg.value == (STAKE_FEE * pubKeys.length), "not enough eth send");
		for(uint i; i < pubKeys.length; i++) {
			register(pubKeys[i]);
		}	
	}

	function register(bytes memory pubKey) public payable {
		require(msg.value >= STAKE_FEE, "not enough eth send");
		require(pubKey.length == 98, "pubKey with wrong format");
		require(pubKey[0] == "0", "make sure it uses 0x");
		require(pubKey[1] == "x", "make sure it uses 0x");
		require(!exists(pubKey), "validator exists");
		uint newId = validators[msg.sender].length;
		Validator memory v = Validator(pubKey, 0, 0, 0, STAKE_FEE, false);
		validators[msg.sender].push(v);
		totalStake += STAKE_FEE;
		emit ValidatorRegistered(msg.sender, string(pubKey), newId);
	}

	function withdrawRewards(uint[] memory validator_ids) nonReentrant public {
		require(validator_ids.length > 0, "empty ids field");
		Validator[] memory v = validators[msg.sender];
		uint val;
		for(uint i; i < validator_ids.length; i++) {
			uint id = validator_ids[i];
			require(bytes(v[id].pubKey).length > 0, "Validator not registered");
			require(v[id].rewards > 0, "Validator reward balance is 0");
      require(v[id].active, "Validator not active");
			totalRewards -= v[id].rewards;
			validators[msg.sender][id].rewards = 0;
			val += v[id].rewards;
      emit Withdrawal(string(v[id].pubKey), v[id].rewards);
		}
		(bool sent, ) = payable(msg.sender).call{value: val, gas: 2300}("");
		require(sent, "Failed to send Ether");
	}

	function exit(uint[] memory validator_ids) nonReentrant external {
		Validator[] memory v = validators[msg.sender];
		uint val;
		for(uint i; i < validator_ids.length; i++) {
			uint id = validator_ids[i];
      // Validator gets deactivated if it hits 0 on rebalance already
			if(v[id].stake > 0) {
				emit ValidatorDeactivated(string(v[id].pubKey));
			}
      // Non-active validators give rewards to pool.
      if(v[id].active) {
        val += (v[id].stake + v[id].rewards);
      } else {
        val += v[id].stake;
      }
			totalStake -= v[id].stake;
			totalRewards -= v[id].rewards;
			delete validators[msg.sender][id];
		}
		// Transfer all rewards and stake
		if(val > 0) {
			(bool sent, ) = payable(msg.sender).call{value: val, gas: 2300}("");
			require(sent, "Failed to send Ether");
		}
	}

	function rebalanceRewards(RebalanceUser[] memory validator, uint fee) onlyOwner external {
		uint tRewards;
    uint tSlashMiss;
    uint tSlashFee;
    uint tUsersRewarded;
		// Rebalance
		for(uint i; i < validator.length; i++) {
			Validator storage v = validators[validator[i].eth1Addr][validator[i].id];
			if(bytes(v.pubKey).length > 0) {
				uint slash_miss = validator[i].slash_miss;
				uint slash_fee = validator[i].slash_fee;
				uint rewards = validator[i].rewards;
        v.active = validator[i].active;
				if((slash_miss + slash_fee) > 0) {
          if(v.active) {
            tSlashMiss += slash_miss;
            tSlashFee += slash_fee;
            slashValidator(v, slash_fee, slash_miss);
          } else {
            totalRewards -= v.rewards;
            v.rewards = 0;
          }
				}
				if(rewards > 0 ) {
					v.rewards += rewards;
					tRewards += rewards;
          tUsersRewarded ++;
				}
			}
		}	
		totalRewards += tRewards;
    totalFees += fee;
    emit Rebalance(tRewards, tUsersRewarded, tSlashMiss, tSlashFee);
	}

  function withdrawFees() onlyOwner external {
    require(totalFees > 0, "Fees have to be bigger than 0");
    (bool sent, ) = payable(msg.sender).call{value: totalFees, gas: 2300}("");
    require(sent, "Failed to send Ether");
    totalFees = 0;
  }

	function addStake(uint[] memory validator_ids) external payable {
		Validator[] storage v = validators[msg.sender];
		for(uint i; i < validator_ids.length; i++) {
			uint id = validator_ids[i];
      require(v[id].stake > (STAKE_FEE - SLASH_FEE), "Validator not allowed to add more stake");
      require((msg.value + v[id].stake) <= STAKE_FEE , "Stake fee bigger than allowed");
      v[id].stake += msg.value;
      totalStake += msg.value;
    }
	}

	function getValidators() external view returns(Validator[] memory) {
		return validators[msg.sender];
	}

	function getValidatorStake(address eth1Addr, uint id) external view returns(uint) {
		return validators[eth1Addr][id].stake;
	}

	function getValidator(address eth1Addr, uint id) external view returns(Validator memory) {
		return validators[eth1Addr][id];
	}

	// All rewards recieved after last rebalance 
	function getRebalanceRewards() public view returns(uint) {
		return address(this).balance - (totalRewards + totalStake + totalFees);
	}

	function slashValidator(Validator storage v, uint s_fee, uint s_miss) internal {
		uint amount_miss = s_miss * SLASH_MISS; 
		uint amount_fee = s_fee * SLASH_FEE; 
		uint totalAmount = amount_miss + amount_fee;
		v.slash_miss +=  s_miss;
		v.slash_fee +=  s_fee;
		
		if (v.stake > totalAmount) {
			totalStake -= totalAmount;
			v.stake -= totalAmount;
		} else {
			totalStake -= v.stake; 
			v.stake = 0;
			emit ValidatorDeactivated(string(v.pubKey));
		}
	}

	function exists(bytes memory pubKey) internal view returns(bool) {
		Validator[] memory v = validators[msg.sender];
		for(uint i; i < v.length; i++) {
			if(keccak256(v[i].pubKey) == keccak256(pubKey)) {
				return true;	
			}
		}		
		return false;
	}

	receive () external payable {
	}
}
