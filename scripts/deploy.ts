async function main() {
	const [deployer] = await ethers.getSigners();
	console.log(`Deploying contracts with the account: ${deployer.address}`);

	const Pool = await ethers.getContractFactory("SmoothlyPool");
	const governance = await(await ethers.getContractFactory("PoolGovernance")).deploy();
	console.log(`Governance deployed with address: ${governance.address}`);
	console.log(`Pool deployed with address: ${await governance.pool()}`);

	//await pool.transferOwnership(governance.address);
	//console.log(`Pool transferOwnership to ${governance.address}`);
}

main()
.then(() => process.exit(0))
.catch((err) => {
	console.error(err);
	process.exit(1);
});
