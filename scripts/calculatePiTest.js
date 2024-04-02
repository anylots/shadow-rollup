const { ethers } = require('ethers');
const { hexlify } = require("ethers/lib/utils");
const fs = require('fs');

async function main() {

    await parseProveData();
}


async function parseProveData() {
    let proveData = loadProveData();
    let pi_data = new Uint8Array(proveData.pi_data);

    let pi_data_array = parse_pi_data(pi_data);
    console.log("pi_data_array: " + pi_data_array);

    let pi_hex = ethers.utils.hexlify(pi_data_array);
    console.log("pi_hex: " + pi_hex);
    //0xc1779e1a30fc12f316643ef1786355ff86f34a120d9427132b8c0c93551c2409
}

async function proveState(shadow_rollup, customHttpProvider) {

    let proveData = loadProveData();

    // 0x39e6bb1271ed76e422f8ceb985001c2e0fb45b481e4706b5e3e787e2c1e90500
    //0x0005e9c1e287e7e3b506471e485bb40f2e1c0085b9cef822e476ed7112bbe639

    let _aggrProof = ethers.utils.arrayify(new Uint8Array(proveData.proof_data));
    let _kzgData = ethers.utils.arrayify(new Uint8Array(proveData.blob_kzg));

    let _commitment = _kzgData.slice(32, 80).reverse();
    let _proof = _kzgData.slice(80, 128).reverse();


    //0x063824c68a781fa7a6a7d9ba309290c05ca9cd054915023a5a033cf614bc2e22
    //0x222ebc14f63c035a3a02154905cda95cc0909230bad9a7a6a71f788ac6243806


    let batchData = {
        prevStateRoot: "0x000e99ef296bcca960ab82643bfb8798fe0e3fdd2cfdf63f36149ad21316ad21",
        postStateRoot: "0x0c331309ce13ebc35b680a146d02b05ccdaec2e4faedddf86c512ec271a1bb5e",
        withdrawalRoot: "0x27ae5ba08d7291c96c8cbddcc148bf48a6d68c7974b94356f53754ef6171d757",
        dataHash: "0x85c4206f1433be4d12d2410ffecd6831e09439e52439e3b3f9ef7e0c26d160c7",
        blobVersionedHash: "0x01ece0bb19bccf011f86762399ee264fc44c0ec388553c543fcfc6c38d135f5b"
    };

    let _x_hex = reverseHexString("0x0005e9c1e287e7e3b506471e485bb40f2e1c0085b9cef822e476ed7112bbe639");
    console.log("_x_hex: " + _x_hex);

    let _y = _kzgData.slice(0, 32).reverse();
    let _y_hex = ethers.utils.hexlify(_y);
    console.log("_y_hex: " + _y_hex);

    const publicInputHash = ethers.utils.solidityKeccak256(["uint64", "bytes", "bytes", "bytes", "bytes", "bytes", "bytes"],
        [53077, batchData.prevStateRoot, batchData.postStateRoot,
            batchData.withdrawalRoot, batchData.dataHash,
            _x_hex, _y_hex]);

    console.log("PublicInputHash: " + publicInputHash);
    let prover_pi = "0xe698da76711a736ca1d780da214aa283e15465e079c1f2dfaca3a1e7f51cf36e"
    // assert.strictEqual(publicInputHash, prover_pi, 'publicInputHash are not correct');



    // const hash = ethers.utils.solidityKeccak256(["uint64", "bytes", "bytes", "bytes", "bytes"],
    //     [53077, "0x000e99ef296bcca960ab82643bfb8798fe0e3fdd2cfdf63f36149ad21316ad21", "0x0c331309ce13ebc35b680a146d02b05ccdaec2e4faedddf86c512ec271a1bb5e",
    //         "0x27ae5ba08d7291c96c8cbddcc148bf48a6d68c7974b94356f53754ef6171d757", "0x85c4206f1433be4d12d2410ffecd6831e09439e52439e3b3f9ef7e0c26d160c7"]);
    //0x772092b67e44766e4439b4abbf1ad90af59c8f3480b881576a94c41a1a808508
    let pi_data = new Uint8Array(proveData.pi_data);
    let pi_data_hex = parse_pi_data(pi_data);
    console.log("pi_data_hex: " + pi_data_hex);

}

function loadProveData() {
    const inputBuffer = fs.readFileSync('./prove.json');
    const inputString = inputBuffer.toString();

    return JSON.parse(inputString);
}


function parse_pi_data(array) {
    const result = [];
    for (let i = 0; i < array.length; i += 32) {
        const group = array.slice(i + 31, i + 32);
        result.push(group[0]);
    }
    console.log(result);
    return result;
}


main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });