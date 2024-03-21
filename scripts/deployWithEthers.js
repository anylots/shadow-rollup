const { BigNumber } = require("ethers")
const { ethers } = require('ethers');
const { hexlify } = require("ethers/lib/utils");
const fs = require('fs');
const ShadowRollup = require("../abi/ShadowRollup.json");
const ZkEvmVerifierV1 = require("../abi/ZkEvmVerifierV1.json");

require("dotenv").config({ path: ".env" });

// This is a script for deploying your contracts. You can adapt it to deploy
// yours, or create new ones.
async function main() {

    ///prepare deployer
    let rollup_address = requireEnv("ROLLUP_ADDRESS");
    let privateKey = requireEnv("PRIVATE_KEY");
    let customHttpProvider = new ethers.providers.JsonRpcProvider(
        requireEnv("L1_RPC")
    );
    const signer = new ethers.Wallet(privateKey, customHttpProvider);
    console.log("signer.address: " + signer.address);

    ///deploy plonk_verifier
    const bytecode = hexlify(fs.readFileSync("./contracts/libs/plonk_verifier.bin"));
    const tx = await signer.sendTransaction({ data: bytecode });
    const receipt = await tx.wait();
    console.log("plonk_verifier address:", receipt.contractAddress);


    ///deploy ZkEvmVerifierV1
    const ZkEvmVerifierV1Factory = new ethers.ContractFactory(ZkEvmVerifierV1.abi, ZkEvmVerifierV1.bytecode, signer);
    zkEvmVerifier = await ZkEvmVerifierV1Factory.deploy(receipt.contractAddress);
    await zkEvmVerifier.deployed();
    console.log("zkEvmVerifier address:", zkEvmVerifier.address);


    ///deploy ShadowRollup
    let ShadowRollupFactory = new ethers.ContractFactory(ShadowRollup.abi, ShadowRollup.bytecode, signer);
    const shadowRollup = await ShadowRollupFactory.deploy(rollup_address, zkEvmVerifier.address);
    console.log("shadowRollup deploying...");

    await shadowRollup.deployed();
    console.log("shadowRollup address:", shadowRollup.address);
}

/**
 * Load environment variables 
 * 
 * @param {*} entry 
 * @returns 
 */
function requireEnv(entry) {
    if (process.env[entry]) {
        return process.env[entry]
    } else {
        throw new Error(`${entry} not defined in .env`)
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
