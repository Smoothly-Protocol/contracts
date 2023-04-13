async function main() {
	const [deployer] = await ethers.getSigners();
	console.log(`Deploying contracts with the account: ${deployer.address}`);

	const pool = await(await ethers.getContractFactory("SmoothlyPoolV2")).deploy();
	const governance = await(await ethers.getContractFactory("PoolGovernance")).deploy(pool.address);
	console.log(`Pool deployed with address: ${pool.address}`);
	console.log(`Governance deployed with address: ${governance.address}`);

	await pool.transferOwnership(governance.address);
	console.log(`Pool transferOwnership to ${governance.address}`);
}

main()
.then(() => process.exit(0))
.catch((err) => {
	console.error(err);
	process.exit(1);
});
