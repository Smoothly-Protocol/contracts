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
    const Pool = await ethers.getContractFactory("SmoothlyPoolV2");
    const Governance = await ethers.getContractFactory("PoolGovernance");
    pool = await Pool.deploy();
    governance = await Governance.deploy(pool.address);
    pool.transferOwnership(governance.address);

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

    it("reverts on pool balance < fee", async () => {
      await governance.addOperators([operator1.address]);
      await time.increase(week);
      await expect(governance.connect(operator1).proposeEpoch([
        withdrawals.root,
        exits.root,
        state,
        ethers.utils.parseEther("2")
      ])).to.be.revertedWith("Failed to send Ether");
    });

    it("propose epoch with only one operator", async () => {
      await governance.addOperators([operator1.address]);
      await time.increase(week);
      await governance.connect(operator1).proposeEpoch([
        withdrawals.root,
        exits.root,
        state,
        fee
      ]);
      expect(
        await governance.getRewards(operator1.address)
      ).to.equal(fee);
      expect(await ethers.provider.getBalance(governance.address)).to.equal(fee);
      expect(await governance.epochNumber()).to.equal(1);
      expect(await ethers.provider.getBalance(pool.address)).to.equal(
        ethers.utils.parseEther("1").sub(fee)
      );
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
      expect(await governance.getRewards(operator1.address)).to.equal(0);
      expect(await governance.getRewards(operator2.address)).to.equal(0);
      expect(await governance.getRewards(operator3.address)).to.equal(0);
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
      expect(await governance.getRewards(operator1.address)).to.equal(fee.div(3));
      expect(await governance.getRewards(operator2.address)).to.equal(fee.div(3));
      expect(await governance.getRewards(operator3.address)).to.equal(fee.div(3));
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
      expect(await governance.getRewards(operator1.address)).to.equal(fee.div(6));
      expect(await governance.getRewards(operator2.address)).to.equal(fee.div(6));
      expect(await governance.getRewards(operator3.address)).to.equal(fee.div(6));
      expect(await governance.getRewards(operator4.address)).to.equal(fee.div(6));
      expect(await governance.getRewards(operator5.address)).to.equal(fee.div(6));
      expect(await governance.getRewards(operator6.address)).to.equal(fee.div(6));
      expect(await governance.epochNumber()).to.equal(1);
      expect(await ethers.provider.getBalance(governance.address)).to.equal(fee);
      expect(await ethers.provider.getBalance(pool.address)).to.equal(
        ethers.utils.parseEther("1").sub(fee)
      );
    });
  });

  describe("Withdrawals", () => {
    it("reverts if operator balance is 0", async () => {
      await governance.addOperators([operator1.address]);
      await expect(
        governance.connect(operator1).withdrawRewards()
      ).to.be.revertedWith("Account balance is 0");
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
      expect(await governance.getRewards(operator1.address)).to.equal(0);
      expect(await governance.getRewards(operator2.address)).to.equal(0);
      expect(await governance.getRewards(operator3.address)).to.equal(0);
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
      await governance.deleteOperators(operators.slice(0,3));
      expect(await governance.getOperators())
      .to.have.all.members(operators.slice(3));
      for(let operator of operators.slice(0,3)) {
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
});


