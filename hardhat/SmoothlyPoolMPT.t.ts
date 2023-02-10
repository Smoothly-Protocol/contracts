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
    const [owner, otherAccount] = await ethers.getSigners();

    // Contract
    const Pool = await ethers.getContractFactory("SmoothlyPoolMPT");
    const pool = await Pool.deploy();

    // MPTrie
    const trie = new Trie({useKeyHashing: true})
    const validator = "0xaad7124198a7f1c4654dc924449fe7734470db03753b470ff91699cc248870e5f45460691099a68b16bff535d5020d61";
    const addr = "hell12" //+ String(i);
    await trie.put(Buffer.from(addr), Buffer.from(RLP.encode([validator,0,0,0,0,"true"])))

    return {owner, otherAccount, pool, trie};
  } 

  describe("MPT verifier", function () {
    it("Should load the fixture", async () => {
      const {owner, pool, trie} = await loadFixture(initMPTrie);
      console.log(owner.address);
      console.log(trie.root());
    });
  });
});
