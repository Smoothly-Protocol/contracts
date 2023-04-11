import { expect } from "chai";
import { ethers } from "hardhat";

import { RLP } from '@ethereumjs/rlp'

import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

import { getProof, buildTrie } from "./utils";

describe("Smoothly Pool MPT Gas calculations with bigger proofs (multiple users)", function () {
  async function deployContract() {
    const signers = await ethers.getSigners();
    const Pool = await ethers.getContractFactory("SmoothlyPoolMPT");
    const pool = await Pool.deploy();
    return { pool , signers };
  } 
  
  it("Withdraws with 1000 users each with 1 validator", async () => {
    const { pool, signers } = await loadFixture(deployContract);
    const trie = await buildTrie(1000, signers, 1);
    
    await signers[0].sendTransaction({to: pool.address, value: ethers.utils.parseEther("1.0")});

    let proof = await getProof(signers[0], trie);
    const validator = RLP.decode(proof[1]);

    // Update validator state
    validator[0][1] = 0.1 * 10 ** 18; // 0.1 ether rewards
    validator[0][5] = 1 // true (validator active)
    await trie.put(Buffer.from(signers[0].address.toLowerCase()), Buffer.from(RLP.encode(validator)))

    // Update root hash in pool
    await pool.setROOT(trie.root());

    proof = await getProof(signers[0], trie);
    await pool.withdrawRewards(proof);
  });

  it("Withdraws with 10000 users each with 10 validators", async () => {
    const { pool, signers } = await loadFixture(deployContract);
    const trie = await buildTrie(10000, signers, 100);
    
    await signers[0].sendTransaction({to: pool.address, value: ethers.utils.parseEther("1.0")});

    let proof = await getProof(signers[0], trie)
    let validator = RLP.decode(proof[1]);

    // Update validator state
    validator = [[
        "0xaad7124198a7f1c4654dc924449fe7734470db03753b470ff91699cc248870e5f45460691099a68b16bff535d5020d61",
        0.1 * 10 ** 18,
        0,
        0,
        0.65 * 10 ** 18,
        1 // bool any non-zero byte except "0x80" is considered true
    ]];
    await trie.put(Buffer.from(signers[0].address.toLowerCase()), Buffer.from(RLP.encode(validator)))

    // Update root hash in pool
    await pool.setROOT(trie.root());

    proof = await getProof(signers[0], trie)
    await pool.withdrawRewards(proof);
  });
}); 
