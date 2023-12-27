import { expect } from "chai";
import { ethers } from "hardhat";
import { time } from "@nomicfoundation/hardhat-network-helpers";
import { StandardMerkleTree } from "@openzeppelin/merkle-tree";

describe("PoolGovernance", () => {
  const week = 7 * 24 * 60 * 60;
  let owner, acc1, acc2, acc3, operator1, operator2, operator3, operator4, operator5, operator6;
  let pool, governance;
  let withdrawals, exits, state, fee;
  
  beforeEach(async () => {
    const Pool = await ethers.getContractFactory("SmoothlyPool");
    const Governance = await ethers.getContractFactory("PoolGovernance");
    governance = await Governance.deploy([], ethers.constants.AddressZero);
    pool = Pool.attach(await governance.pool());

    [owner, acc1, acc2, acc3, operator1, operator2, operator3, operator4, operator5, operator6] = await ethers.getSigners();
    await owner.sendTransaction({
      value: ethers.utils.parseEther("1"),
      to: pool.address
    });

    withdrawals = [
      [acc1.address, [100, 300], ethers.utils.parseEther("1.25")], 
      [acc2.address, [200], ethers.utils.parseEther("0.25")], 
      [acc3.address, [400], ethers.utils.parseEther("0.5")], 
    ];
    exits = [
      [acc3.address, [100, 300], ethers.utils.parseEther("1.25")], 
    ];

    state = "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421";
    withdrawals = StandardMerkleTree.of(withdrawals, ["address", "uint256[]", "uint256"]);
    exits = StandardMerkleTree.of(exits, ["address", "uint256[]", "uint256"]);
    fee = ethers.utils.parseEther("0.01");
  });

  describe("Epoch Proposal", () => {
    it("reverts on unauthorized operator", async () => {
      await expect(governance.proposeEpoch([
        withdrawals.root,
        exits.root,
        state,
        fee 
      ])).to.be.revertedWithCustomError(governance, 'Unauthorized');
    });

    it("reverts on epoch timelock not reached", async () => {
      await governance.addOperators([operator1.address]);
      await expect(governance.connect(operator1).proposeEpoch([
        withdrawals.root,
        exits.root,
        state,
        fee 
      ])).to.be.revertedWithCustomError(governance, 'EpochTimelockNotReached');
    });

    it("reverts on only one operator", async () => {
      await governance.addOperators([operator1.address]);
      await time.increase(week);
      await expect(governance.connect(operator1).proposeEpoch([
        withdrawals.root,
        exits.root,
        state,
        fee 
      ])).to.be.revertedWithCustomError(governance, 'NotEnoughOperators');
    });


    it("reverts on pool balance < fee", async () => {
      await governance.addOperators([operator1.address, operator2.address]);
      await time.increase(week);
      await governance.connect(operator1).proposeEpoch([
          withdrawals.root,
          exits.root,
          state,
          ethers.utils.parseEther("2")
      ]);
      await expect(governance.connect(operator2).proposeEpoch([
        withdrawals.root,
        exits.root,
        state,
        ethers.utils.parseEther("2")
      ])).to.be.revertedWithCustomError(pool, 'CallTransferFailed');
    });

    it("allows rebalance with 0 fee value", async () => {
      await governance.addOperators([operator1.address, operator2.address]);
      await time.increase(week);
      await governance.connect(operator1).proposeEpoch([
          withdrawals.root,
          exits.root,
          state,
          ethers.utils.parseEther("0")
      ]);
      await expect(governance.connect(operator2).proposeEpoch([
        withdrawals.root,
        exits.root,
        state,
        ethers.utils.parseEther("0")
      ])).to.emit(pool, 'Epoch').withArgs(1, state, 0);
    });

    it("propose epoch with 3 operators don't agree", async () => {
      await governance.addOperators([
        operator1.address,
        operator2.address,
        operator3.address
      ]);
      await time.increase(week);
      await governance.connect(operator1).proposeEpoch([
        withdrawals.root,
        exits.root,
        state,
        fee
      ]);
      await governance.connect(operator2).proposeEpoch([
        withdrawals.root,
        exits.root,
        ethers.utils.formatBytes32String('lol'),
        fee
      ]);
      await governance.connect(operator2).proposeEpoch([
        withdrawals.root,
        exits.root,
        ethers.utils.formatBytes32String('wack'),
        fee
      ]);
      expect(await governance.operatorRewards(operator1.address)).to.equal(0);
      expect(await governance.operatorRewards(operator2.address)).to.equal(0);
      expect(await governance.operatorRewards(operator3.address)).to.equal(0);
      expect(await governance.epochNumber()).to.equal(0);
      expect(await ethers.provider.getBalance(governance.address)).to.equal(0);
      expect(await ethers.provider.getBalance(pool.address)).to.equal(
        ethers.utils.parseEther("1")
      );
    });

    it("propose epoch with 3 operators agree at least 2", async () => {
      await governance.addOperators([
        operator1.address,
        operator2.address,
        operator3.address
      ]);
      await time.increase(week);
      await governance.connect(operator1).proposeEpoch([
        withdrawals.root,
        exits.root,
        state,
        fee
      ]);
      await governance.connect(operator2).proposeEpoch([
        withdrawals.root,
        exits.root,
        state,
        fee
      ]);
      expect(await governance.operatorRewards(operator1.address)).to.equal(fee.div(3));
      expect(await governance.operatorRewards(operator2.address)).to.equal(fee.div(3));
      expect(await governance.operatorRewards(operator3.address)).to.equal(fee.div(3));
      expect(await governance.epochNumber()).to.equal(1);
      expect(await ethers.provider.getBalance(governance.address)).to.equal(fee);
      expect(await ethers.provider.getBalance(pool.address)).to.equal(
        ethers.utils.parseEther("1").sub(fee)
      );
    });

    it("propose epoch with 6 operators agree at least 4", async () => {
      await governance.addOperators([
        operator1.address,
        operator2.address,
        operator3.address,
        operator4.address,
        operator5.address,
        operator6.address
      ]);
      await time.increase(week);
      await governance.connect(operator1).proposeEpoch([
        withdrawals.root,
        exits.root,
        state,
        fee
      ]);
      await governance.connect(operator2).proposeEpoch([
        withdrawals.root,
        exits.root,
        state,
        fee
      ]);
      await governance.connect(operator3).proposeEpoch([
        withdrawals.root,
        exits.root,
        state,
        fee
      ]);
      await governance.connect(operator4).proposeEpoch([
        withdrawals.root,
        exits.root,
        state,
        fee
      ]);
      expect(await governance.operatorRewards(operator1.address)).to.equal(fee.div(6));
      expect(await governance.operatorRewards(operator2.address)).to.equal(fee.div(6));
      expect(await governance.operatorRewards(operator3.address)).to.equal(fee.div(6));
      expect(await governance.operatorRewards(operator4.address)).to.equal(fee.div(6));
      expect(await governance.operatorRewards(operator5.address)).to.equal(fee.div(6));
      expect(await governance.operatorRewards(operator6.address)).to.equal(fee.div(6));
      expect(await governance.epochNumber()).to.equal(1);
      expect(await ethers.provider.getBalance(governance.address)).to.equal(fee);
      expect(await ethers.provider.getBalance(pool.address)).to.equal(
        ethers.utils.parseEther("1").sub(fee)
      );
    });

		it("Operators can't cast an extra vote to get voting majority", async () => {
			await governance.addOperators([
				operator1.address,
				operator2.address,
				operator3.address,
			]);
			await time.increase(week);
			await governance
				.connect(operator1)
				.proposeEpoch([withdrawals.root, exits.root, state, fee]);

			expect(await governance.epochNumber()).to.equal(0);
			// operator1 casts a second vote to get 66% vote ratio
			await governance
				.connect(operator1)
				.proposeEpoch([withdrawals.root, exits.root, state, fee]);

			// validate that the epoch increased (vote passed)
			expect(await governance.epochNumber()).to.equal(0);
		});
  });

  describe("Withdrawals", () => {
    it("reverts if operator balance is 0", async () => {
      await governance.addOperators([operator1.address]);
      await expect(
        governance.connect(operator1).withdrawRewards()
      ).to.be.revertedWithCustomError(governance, 'ZeroAmount');
    });

    it("operator rewards should be transferred to pool on deletion", async () => {
      await governance.addOperators([operator1.address, operator2.address]);
      await time.increase(week);
      await governance.connect(operator1).proposeEpoch([
        withdrawals.root,
        exits.root,
        state,
        fee
      ]);
      await governance.connect(operator2).proposeEpoch([
        withdrawals.root,
        exits.root,
        state,
        fee
      ]);
      await governance.deleteOperators([operator2.address]);
      expect(
        await governance.operatorRewards(operator2.address)
      ).to.equal(0);
      expect(
        await governance.operatorRewards(operator1.address)
      ).to.not.equal(0);
      expect(await ethers.provider.getBalance(governance.address)).to.equal(fee.div(2));
      expect(await governance.epochNumber()).to.equal(1);
      expect(await ethers.provider.getBalance(pool.address)).to.equal(
        ethers.utils.parseEther("1").sub(fee).add(fee.div(2))
      );
      await expect(governance.connect(operator2).withdrawRewards())
        .to.be.revertedWithCustomError(governance, 'Unauthorized');
    });

    it("withdraws rewards correctly", async () => {
      await governance.addOperators([
        operator1.address,
        operator2.address,
        operator3.address
      ]);
      await time.increase(week);
      await governance.connect(operator1).proposeEpoch([
        withdrawals.root,
        exits.root,
        state,
        fee
      ]);
      await governance.connect(operator2).proposeEpoch([
        withdrawals.root,
        exits.root,
        state,
        fee
      ]);
      await governance.connect(operator1).withdrawRewards()
      await governance.connect(operator2).withdrawRewards()
      await governance.connect(operator3).withdrawRewards()
      expect(await governance.operatorRewards(operator1.address)).to.equal(0);
      expect(await governance.operatorRewards(operator2.address)).to.equal(0);
      expect(await governance.operatorRewards(operator3.address)).to.equal(0);
      // Rounding Precision loss of 1 wei here 
      //expect(await ethers.provider.getBalance(governance.address)).to.equal(0);
      expect(await ethers.provider.getBalance(pool.address)).to.equal(
        ethers.utils.parseEther("1").sub(fee)
      );
    });
  });

  describe("Admin utils", () => {
    let operators;
    beforeEach(async() => {
      operators = [
        acc1.address,
        acc2.address,
        acc3.address,
        operator1.address,
        operator2.address,
        operator3.address
      ];
      await governance.addOperators(operators);
    })

    it("reverts on adding an existing operator", async() => {
      await expect(
        governance.addOperators([acc1.address])
      ).to.be.revertedWithCustomError(governance, 'ExistingOperator')
      .withArgs(acc1.address)
    });

    it("add Operators correctly", async() => {
      for(let operator of operators) {
        expect(await governance.isOperator(operator)).to.equal(true);
      }
    });

    it("delete Operators correctly", async() => {
      // Single delete first
      const remove1 = [operators[0]];
      await governance.deleteOperators(remove1);
      expect(await governance.getOperators())
      .to.have.all.members(operators.slice(1));

      // Single delete last
      const remove2 = [operators[5]];
      await governance.deleteOperators(remove2);
      expect(await governance.getOperators())
      .to.have.all.members(operators.slice(1,5));

      // Multiple deletes
      const remove3 = operators.slice(2,4);
      await governance.deleteOperators(remove3);
      expect(await governance.getOperators())
      .to.have.all.members([operators[1], operators[4]]);
      
      // Multiple last addresses deletes
      const remove4 = [operators[1], operators[4]];
      await governance.deleteOperators(remove4);
      expect(await governance.getOperators())
      .to.deep.equal([]);

      for(let operator of operators) {
        expect(await governance.isOperator(operator)).to.equal(false);
      }
    });

    it("transfers Ownership of Pool", async() => {
      await governance.transferPoolOwnership(owner.address);
      await time.increase(week);
      await governance.connect(operator1).proposeEpoch([
        withdrawals.root,
        exits.root,
        state,
        fee
      ])
      await governance.connect(operator2).proposeEpoch([
        withdrawals.root,
        exits.root,
        state,
        fee
      ])
      await governance.connect(operator3).proposeEpoch([
        withdrawals.root,
        exits.root,
        state,
        fee
      ])
      await expect(governance.connect(acc1).proposeEpoch([
        withdrawals.root,
        exits.root,
        state,
        fee
      ])).to.be.revertedWith("Ownable: caller is not the owner");
      expect(await pool.owner()).to.equal(owner.address);
    });
  });

  describe("Governance Update", () => {
    let operators; 
    before(async() => {
      operators = [
        acc1.address,
        acc2.address,
        acc3.address,
        operator1.address,
        operator2.address,
        operator3.address
      ];
    });

    it("updates governance contract correctly", async() => {
      let Governance2 = await ethers.getContractFactory("PoolGovernance");
      let governance2 = await Governance2.deploy(operators, pool.address);

      await governance.transferPoolOwnership(governance2.address);

      expect(await governance2.pool()).to.equal(pool.address);
      expect(await pool.owner()).to.equal(governance2.address);
      expect(await governance2.getOperators()).to.have.all.members(operators);
    });

    it("should be able to propose an epoch updated contract", async() => {
      let Governance2 = await ethers.getContractFactory("PoolGovernance");
      let governance2 = await Governance2.deploy(operators, pool.address);

      await governance.addOperators(operators);

      await governance.transferPoolOwnership(governance2.address);
      await time.increase(week);

      // Old contract shouldn't be able to proposeEpoch
      await governance.connect(operator1).proposeEpoch([
        withdrawals.root,
        exits.root,
        state,
        fee
      ])
      await governance.connect(operator2).proposeEpoch([
        withdrawals.root,
        exits.root,
        state,
        fee
      ])
      await governance.connect(operator3).proposeEpoch([
        withdrawals.root,
        exits.root,
        state,
        fee
      ])
      await expect(governance.connect(acc1).proposeEpoch([
        withdrawals.root,
        exits.root,
        state,
        fee
      ])).to.be.revertedWith("Ownable: caller is not the owner");
      expect(await pool.owner()).to.equal(governance2.address);

      // New contract should be able to proposeEpoch
      await governance2.connect(operator1).proposeEpoch([
        withdrawals.root,
        exits.root,
        state,
        fee
      ])
      await governance2.connect(operator2).proposeEpoch([
        withdrawals.root,
        exits.root,
        state,
        fee
      ])
      await governance2.connect(operator3).proposeEpoch([
        withdrawals.root,
        exits.root,
        state,
        fee
      ])
      await expect(governance2.connect(acc1).proposeEpoch([
        withdrawals.root,
        exits.root,
        state,
        fee
      ])).to.emit(pool, 'Epoch').withArgs(1, state, fee);
    });

  });
});


