async function main() {
    const operators = [
      '0x0A9aE3DbE453988Fda05549eFdFa2bdCc1Fb5C27',
      '0xeCbb058Fc429941124a2b8d0984354c3132F536f',
      '0x9Be3570F5454fd668673fEb9C43805C533e53FFD',
      '0x648aA14e4424e0825A5cE739C8C68610e143FB79',
      '0x6308F1c6f283583C8bf8E31Da793B87718b051eD',
      '0xd6B927B9342DEDB758A86e99B2A2abe0D1532b2A'
    ];
    const [deployer] = await ethers.getSigners();
    const Governance = await ethers.getContractFactory("PoolGovernance");
    const governance = Governance.attach("0xA20672D73fD75b9e80F52492CE77cBFcF804d679");
    const tx = await governance.deleteOperators(operators);
    console.log(tx);
}

main();
