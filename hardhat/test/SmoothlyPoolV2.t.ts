import { expect } from "chai";
import { ethers } from "hardhat";
import { StandardMerkleTree } from "@openzeppelin/merkle-tree";

describe("SmoothlyPoolV2", () => {
  let owner, acc1, acc2, acc3, pool, values, tree;
  const STAKE_FEE = ethers.utils.parseEther("0.65");

  beforeEach(async () => {
    const Pool = await ethers.getContractFactory("SmoothlyPoolV2");
    pool = await Pool.deploy();
    [owner, acc1, acc2, acc3] = await ethers.getSigners();
    await owner.sendTransaction({
      value: ethers.utils.parseEther("1"),
      to: pool.address
    });
    // Merkle Tree data
    values = [
     [acc1.address, ethers.utils.parseEther("1"), STAKE_FEE, true], 
     [acc2.address, ethers.utils.parseEther("0.25"), STAKE_FEE, true], 
    ];
    empty = StandardMerkleTree.of([], ["address", "uint256", "uint256", "bool"])
    console.log(empty.root);
    tree = StandardMerkleTree.of(values, ["address", "uint256", "uint256", "bool"]);
  });

  describe("Registration", () => {

  });

  describe("Withdrawal", () => {
    it("Withdraws funds correctly with true proof", async () => {
      const proof = getProof(tree, acc1.address);
      const data = values[0].splice(1);
      await pool.setRoot(tree.root);
      await pool.connect(acc1).withdrawRewards(proof, data);  
    })
  });

  describe("Exit", () => {

  });

  describe("Add Stake", () => {

  });

});


function getProof(tree: StandardMerkleTree, addr: string): any {
  for (const [i, v] of tree.entries()) {
    if(v[0] === addr) {
      return tree.getProof(i);
    }
  }
}
