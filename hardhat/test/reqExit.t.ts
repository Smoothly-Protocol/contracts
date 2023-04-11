import { expect } from "chai";
import { ethers } from "hardhat";

describe("Req Exits", () => {
  let pool;
  before(async () => {
    const Pool = await ethers.getContractFactory("SmoothlyPoolMPT");
    pool = await Pool.deploy();
  })

  it("calls correctly reqExits", async () => {
    await pool.reqExit([4]);
  })
})
