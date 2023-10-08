export async function deployer(multisig: string) {
  try {
    const [deployer] = await ethers.getSigners();
    console.log(`Deploying contracts with the account: ${deployer.address}`);

    const governance = await(await ethers.getContractFactory("PoolGovernance")).deploy();
    console.log(`Governance deployed with address: ${governance.address}`);
    console.log(`Pool deployed with address: ${await governance.pool()}`);

    const tx = await governance.transferOwnership(multisig);
    await tx.wait();
    console.log(`Pool transferOwnership to ${await governance.owner()}`);
  } catch(err: any) {
    console.log(err);
  }
}

