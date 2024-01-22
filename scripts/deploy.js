const rollup_address = '0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9';
const verifier_address = '0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9';


// This is a script for deploying your contracts. You can adapt it to deploy
// yours, or create new ones.
async function main() {
  const [deployer] = await ethers.getSigners();

  console.log(
    "Deploying contracts with the account:",
    await deployer.getAddress()
  );

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const ShadowRollup = await ethers.getContractFactory("ShadowRollup");
  const shadowRollup = await ShadowRollup.deploy(rollup_address, verifier_address);
  await shadowRollup.deployed();
  console.log("shadowRollup address:", shadowRollup.address);
}



main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
