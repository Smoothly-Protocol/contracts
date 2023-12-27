export async function deployer(multisig: string) {
  try {
    const operators = [
      '0x2DE6102C4f1a17d0406d60F322358011a13A4cc3',
      '0x962757858d38c5967b2f5fdC7fEcf63732A97308',
    ];
    const pool = '0x894F0786cb41b1c1760E70d61cB2952749Da6382'; 

    const [deployer] = await ethers.getSigners();
    console.log(`Deploying contracts with the account: ${deployer.address}`);

    const governance = await(await ethers.getContractFactory("PoolGovernance")).deploy(operators, pool);
    console.log(`Governance deployed with address: ${governance.address}`);
    console.log(`Pool deployed with address: ${await governance.pool()}`);
  } catch(err: any) {
    console.log(err);
  }
}

