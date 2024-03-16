
export async function deployer(multisig: string) {
  try {
    /*
    const operators = [
      '0x2DE6102C4f1a17d0406d60F322358011a13A4cc3',
      '0x962757858d38c5967b2f5fdC7fEcf63732A97308',
      '0xeb9a574862A691c55D3F9Fd1ba828Ad04aC31115',
      '0xe7874e054D974C137e2bA0B0c0C2693B9C452932',
      '0xAA164757E3e85B954995dd6aF001E474491D7aa2',
      '0x0A9aE3DbE453988Fda05549eFdFa2bdCc1Fb5C27'
    ];
    const pool = '0x43670D6f39Bca19EE26462f62339e90A39B01e34'; 
    */
    const operators = [
      '0x2DE6102C4f1a17d0406d60F322358011a13A4cc3',
      '0x962757858d38c5967b2f5fdC7fEcf63732A97308',
    ];
    const pool = ethers.constants.AddressZero; 

    const [deployer] = await ethers.getSigners();
    console.log(`Deploying contracts with the account: ${deployer.address}`);

    const governance = await(await ethers.getContractFactory("PoolGovernance")).deploy(operators, pool);
    console.log(`Governance deployed with address: ${governance.address}`);
    console.log(`Pool deployed with address: ${await governance.pool()}`);
  } catch(err: any) {
    console.log(err);
  }
}

