import { Trie } from '@ethereumjs/trie';
import { RLP } from '@ethereumjs/rlp'

import { expect } from "chai";
import { ethers } from "hardhat";

import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

const keccak256 = ethers.utils.keccak256;

describe("Load Scenario", function () {
  // Fixture initializes @ethereum/trie mpt with some users.
  async function initMPTrie() {
    // Accounts 
    const [owner, user, user2 ] = await ethers.getSigners();

    // Contract
    const Pool = await ethers.getContractFactory("SmoothlyPoolMPT");
    const pool = await Pool.deploy();

    // MPTrie
    const trie = new Trie({useKeyHashing: true})
    // User with 1 validator
    const validators = [
      [
        "0xaad7124198a7f1c4654dc924449fe7734470db03753b470ff91699cc248870e5f45460691099a68b16bff535d5020d61",
        5,
        1,
        0,
        0.50 * 10 ** 18,
        1 // bool any non-zero byte except "0x80" is considered true
      ],
    ]
    const validators2 = [
      [
        "0xaad7124198a7f1c4654dc924449fe7734470db03753b470ff91699cc248870e5f45460691099a68b16bff535d5020d61",
        0,
        1,
        0,
        0.65 * 10 ** 18,
        1 // bool any non-zero byte except "0x80" is considered true
      ],
    ]
    // Insert to trie
    await trie.put(Buffer.from(user.address.toLowerCase()), Buffer.from(RLP.encode(validators)))
    await trie.put(Buffer.from(owner.address.toLowerCase()), Buffer.from(RLP.encode(validators2)))

    return {owner, user, user2, pool, trie};
  } 

  describe("MPT verifier", function () {
    it("Withdraws with proof", async () => {
      const {owner, user, user2, pool, trie} = await loadFixture(initMPTrie);
      await owner.sendTransaction({to: pool.address, value: ethers.utils.parseEther("1.0")});

      console.log("root:", trie.root());
      const key = Buffer.from(user.address.toLowerCase());
      console.log("addr", user.address);
      console.log("key-regular", key.toString('hex'));
      console.log("key", keccak256(key));
      const proof = await trie.createProof(key);
      const value = await trie.verifyProof(trie.root(), key, proof) as Buffer;

      await pool.setROOT(trie.root());
      await pool.connect(user).withdrawRewards([proof, value]);
    });

    it("Adds stake with proof", async () => {
      const {owner, user, user2, pool, trie} = await loadFixture(initMPTrie);

      const key = Buffer.from(owner.address.toLowerCase());
      const proof = await trie.createProof(key);
      const value = await trie.verifyProof(trie.root(), key, proof) as Buffer;
      const pubKey = "0xaad7124198a7f1c4654dc924449fe7734470db03753b470ff91699cc248870e5f45460691099a68b16bff535d5020d61";

      await pool.setROOT(trie.root());
      await pool.connect(owner).addStake([proof, value], pubKey, {value: ethers.utils.parseEther("0.15")});
    });
  });
});
