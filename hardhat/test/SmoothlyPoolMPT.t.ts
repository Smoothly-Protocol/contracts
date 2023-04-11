import { Trie } from '@ethereumjs/trie';
import { RLP } from '@ethereumjs/rlp'

import { expect } from "chai";
import { ethers } from "hardhat";

import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

import { getProof } from "./utils";

describe("Smoothly Pool MPT version", function () {
  // Fixture initializes @ethereum/trie mpt with 2 users.
  async function initMPTrie() {
    // Accounts 
    const [owner, user, user2 ] = await ethers.getSigners();

    // Contract
    const Pool = await ethers.getContractFactory("SmoothlyPoolMPT");
    const pool = await Pool.deploy();

    // MPTrie
    const trie = new Trie({useKeyHashing: true})
    const validator = [
      [
        38950,
        0,
        0,
        0,
        0.65 * 10 ** 18,
        0 // bool any non-zero byte except "0x80" is considered true
      ],
    ]
    const validator2 = [
      [
        38960,
        0,
        0,
        0,
        0.65 * 10 ** 18,
        0 // bool any non-zero byte except "0x80" is considered true
      ],
    ]
    // Insert to trie
    await trie.put(Buffer.from(user.address.toLowerCase()), Buffer.from(RLP.encode(validator)))
    await trie.put(Buffer.from(owner.address.toLowerCase()), Buffer.from(RLP.encode(validator2)))

    // Update root hash in pool
    await pool.setROOT(trie.root());

    return {owner, user, user2, pool, trie, validator, validator2};
  } 

  describe("Withdrawals", function () {
    it("Reverts trying to withdraw with proof of other user", async () => {
      const {user, user2, pool, trie} = await loadFixture(initMPTrie);
      const proof = await getProof(user, trie);
      await expect(pool.connect(user2).withdrawRewards(proof))
        .to.be.revertedWith("invalid root hash");
    });

    it("Reverts if validator doesn't have any rewards", async () => {
      const {user, pool, trie} = await loadFixture(initMPTrie);
      const proof = await getProof(user, trie);
      await expect(pool.connect(user).withdrawRewards(proof))
        .to.be.revertedWith("0 Rewards or inactive validators");
    });

    it("Reverts if validator state is not updated to contract", async () => {
      const {user, validator, pool, trie} = await loadFixture(initMPTrie);

      validator[0][1] = 0.1 * 10 ** 18; // 0.1 ether
      await trie.put(Buffer.from(user.address.toLowerCase()), Buffer.from(RLP.encode(validator)))

      const proof = await getProof(user, trie);
      await expect(pool.connect(user).withdrawRewards(proof))
        .to.be.revertedWith("invalid root hash");
    });

    it("Reverts if validator is not active", async () => {
      const {user, validator, pool, trie} = await loadFixture(initMPTrie);

      validator[0][1] = 0.1 * 10 ** 18; // 0.1 ether
      await trie.put(Buffer.from(user.address.toLowerCase()), Buffer.from(RLP.encode(validator)))

      await pool.setROOT(trie.root());

      const proof = await getProof(user, trie);
      await expect(pool.connect(user).withdrawRewards(proof))
        .to.be.revertedWith("0 Rewards or inactive validators");
    });

    it("Withdraws correctly", async () => {
      const {user, owner, validator, pool, trie} = await loadFixture(initMPTrie);

      validator[0][1] = 0.1 * 10 ** 18; // 0.1 ether
      validator[0][5] = 1 // true (validator active)
      await trie.put(Buffer.from(user.address.toLowerCase()), Buffer.from(RLP.encode(validator)))

      await owner.sendTransaction({to: pool.address, value: ethers.utils.parseEther("1.0")});
      await pool.setROOT(trie.root());

      const proof = await getProof(user, trie);
      
      const userInitBalance = await ethers.provider.getBalance(user.address);
      const tx = await pool.connect(user).withdrawRewards(proof);
      const reciept = await tx.wait();
      const gasPaid = reciept.cumulativeGasUsed.mul(reciept.effectiveGasPrice);

      const poolBalance = await ethers.provider.getBalance(pool.address);
      const userFinalBalance = await ethers.provider.getBalance(user.address);

      expect(poolBalance).to.equal(ethers.utils.parseEther("0.9"));
      expect(userFinalBalance)
        .to.equal(userInitBalance.sub(gasPaid).add(ethers.utils.parseEther("0.1")));
    });

    it("Withdraws correctly after one epoch", async () => {
      const {user, owner, validator, pool, trie} = await loadFixture(initMPTrie);
      await owner.sendTransaction({to: pool.address, value: ethers.utils.parseEther("1.0")});

      validator[0][1] = 0.1 * 10 ** 18; // 0.1 ether
      validator[0][5] = 1 // true (validator active)
      await trie.put(Buffer.from(user.address.toLowerCase()), Buffer.from(RLP.encode(validator)))

      // First Epoch
      await pool.setROOT(trie.root());
      const proof1 = await getProof(user, trie);
      await pool.connect(user).withdrawRewards(proof1);

      // Second Epoch
      await pool.setROOT(trie.root());
      const proof2 = await getProof(user, trie);
      const userInitBalance = await ethers.provider.getBalance(user.address);
      const tx = await pool.connect(user).withdrawRewards(proof2);
      const reciept = await tx.wait();
      const gasPaid = reciept.cumulativeGasUsed.mul(reciept.effectiveGasPrice);

      const poolBalance = await ethers.provider.getBalance(pool.address);
      const userFinalBalance = await ethers.provider.getBalance(user.address);

      expect(poolBalance).to.equal(ethers.utils.parseEther("0.8"));
      expect(userFinalBalance)
        .to.equal(userInitBalance.sub(gasPaid).add(ethers.utils.parseEther("0.1")));
    });

    it("Reverts when user trying to withdraw more than once", async () => {
      const {user, owner, validator, pool, trie} = await loadFixture(initMPTrie);

      validator[0][1] = 0.1 * 10 ** 18; // 0.1 ether
      validator[0][5] = 1 // true (validator active)
      await trie.put(Buffer.from(user.address.toLowerCase()), Buffer.from(RLP.encode(validator)))

      await owner.sendTransaction({to: pool.address, value: ethers.utils.parseEther("1.0")});
      await pool.setROOT(trie.root());

      const proof = await getProof(user, trie);
      
      await pool.connect(user).withdrawRewards(proof);

      await expect(pool.connect(user).withdrawRewards(proof))
        .to.be.revertedWith("Already claimed withdrawal for current epoch");
    });

  });
  
  describe("Adding Stake", function () {
    it("Reverts if stake is satisfied", async () => {
      const {user, validator, pool, trie} = await loadFixture(initMPTrie);
      await pool.setROOT(trie.root());
      const proof = await getProof(user, trie);
      await expect(pool.connect(user).addStake(proof, validator[0][0], {value: ethers.utils.parseEther("0.15")}))
        .to.be.revertedWith("Stake fee too big");
    });

    it("Reverts if amount is 0", async () => {
      const {user, validator, pool, trie} = await loadFixture(initMPTrie);
      await pool.setROOT(trie.root());
      const proof = await getProof(user, trie);
      await expect(pool.connect(user).addStake(proof, validator[0][0]))
        .to.be.revertedWith("0 amount");
    });

    it("Adds stake correctly", async () => {
      const {user, validator, pool, trie} = await loadFixture(initMPTrie);
      validator[0][4] = 0.5 * 10 ** 18; // 0.5 ether
      await trie.put(Buffer.from(user.address.toLowerCase()), Buffer.from(RLP.encode(validator)))
      await pool.setROOT(trie.root());
      const proof = await getProof(user, trie);
      await expect(pool.connect(user).addStake(proof, validator[0][0], {value: ethers.utils.parseEther("0.15")}))
        .to.emit(pool, "StakeAdded").withArgs(user.address, validator[0][0], ethers.utils.parseEther("0.15"));
    });
  });

  describe("Exits", function () {
    it("Reverts on Exit without previous request", async () => {
      const {user, validator, pool, trie} = await loadFixture(initMPTrie);
      const proof = await getProof(user, trie);
      await pool.setROOT(trie.root());
      //await pool.connect(user).reqExit([validator[0][0]]);
      await expect(pool.connect(user).exit(proof, [validator[0][0]]))
        .to.be.revertedWith("Exit not allowed");
    });

    it("Reverts on Exit on current epoch with request for exit on the next", async () => {
      const {user, validator, pool, trie} = await loadFixture(initMPTrie);
      validator[0][4] = 0.65 * 10 ** 18; // 0.5 ether
      await trie.put(Buffer.from(user.address.toLowerCase()), Buffer.from(RLP.encode(validator)))
      const proof = await getProof(user, trie);
      await pool.setROOT(trie.root());
      await pool.connect(user).reqExit([validator[0][0]]);
      await expect(pool.connect(user).exit(proof, [validator[0][0]]))
        .to.be.revertedWith("Exit not allowed");
    });

    it("Reverts trying to exit a validator that is not registered", async () => {
      const {user, validator2, pool, trie} = await loadFixture(initMPTrie);
      const proof = await getProof(user, trie);
      await pool.setROOT(trie.root());
      await expect(pool.connect(user).exit(proof, [validator2[0][0]]))
        .to.be.revertedWith("Validator not found");
    });

    it("Allows validator to exit successfully on next epoch", async () => {
      const {user, owner, validator, pool, trie} = await loadFixture(initMPTrie);
      await owner.sendTransaction({to: pool.address, value: ethers.utils.parseEther("1.0")});
      const proof = await getProof(user, trie);
      await pool.setROOT(trie.root());
      await pool.connect(user).reqExit([validator[0][0]]);
      await pool.setROOT(trie.root());
      await expect(pool.connect(user).exit(proof, [validator[0][0]]))
        .to.changeEtherBalance(user, ethers.utils.parseEther("0.65").add(ethers.utils.parseEther("0.1")))
    });
  });

});

