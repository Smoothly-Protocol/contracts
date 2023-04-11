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
      value: ethers.utils.parseEther("1.6"),
      to: pool.address
    });
    // Merkle Tree data
    values = [
     [acc1.address, [100, 300], ethers.utils.parseEther("1.25")], 
     [acc2.address, [200], ethers.utils.parseEther("0.25")], 
    ];
    tree = StandardMerkleTree.of(values, ["address", "uint256[]", "uint256"]);
  });


  describe("Withdrawal", () => {
    it("Withdraws funds correctly with true proof", async () => {
      const proof = tree.getProof(values[0]); 
      console.log(proof);
      await pool.updateEpoch(
        tree.root, 
        ethers.utils.formatBytes32String("0x"), 
        ethers.utils.formatBytes32String("0x"), 
        ethers.utils.parseEther("0.1")
      );
      await pool.connect(acc1).withdrawRewards(
        proof, 
        [100, 300],
        ethers.utils.parseEther("1.25") 
      );  
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
