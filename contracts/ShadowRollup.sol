// contracts/GLDToken.sol
// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;
import "@openzeppelin/contracts/access/Ownable.sol";
import {IRollup} from "./IRollup.sol";
import {IZkEvmVerifier} from "./libs/IZkEvmVerifier.sol";
import "hardhat/console.sol";

/// @title ShadowRollup
/// @notice This contract maintains data for shadow rollup.
contract ShadowRollup is Ownable {
    uint256 constant BLS_MODULUS =
        52435875175126190479447740508185965837690552500527637822603658699938581184513;

    /// @notice The address of rollup.
    address public rollup;
    /// @notice The address of zkevmVerifier.
    address public zkevm_verifier;

    struct BatchStore {
        bytes32 prevStateRoot;
        bytes32 postStateRoot;
        bytes32 withdrawalRoot;
        bytes32 dataHash;
        bytes32 blobVersionedHash;
    }

    mapping(uint256 => BatchStore) public committedBatchStores;

    /**
     * @notice Store Challenge Information.(batchIndex => BatchChallenge)
     */
    mapping(uint256 => BatchChallenge) public challenges;

    struct BatchChallenge {
        uint64 batchIndex;
        address challenger;
        uint256 challengeDeposit;
        uint256 startTime;
        bool finished;
    }

    /// @notice Emitted when the state of Chanllenge is updated.
    /// @param batchIndex The index of the batch.
    /// @param challenger The address of challenger.
    /// @param challengeDeposit The deposit of challenger.
    event ChallengeState(
        uint64 indexed batchIndex,
        address challenger,
        uint256 challengeDeposit
    );

    /***************
     * Constructor *
     ***************/

    constructor(address _rollup, address _verifier) {
        rollup = _rollup;
        zkevm_verifier = _verifier;
    }

    /// @notice Commit a batch of transactions on layer 1.
    ///
    /// @param _batchIndex The index of batch
    /// @param _batchData The batch data
    function commitBatch(
        uint64 _batchIndex,
        BatchStore calldata _batchData
    ) external {
        committedBatchStores[_batchIndex] = _batchData;
    }

    // challengeState challenges a batch by submitting a deposit.
    function challengeState(uint64 batchIndex) external payable onlyOwner {
        challenges[batchIndex] = BatchChallenge(
            batchIndex,
            _msgSender(),
            msg.value,
            block.timestamp,
            false
        );
        emit ChallengeState(batchIndex, _msgSender(), msg.value);
    }

    // proveState proves a batch by submitting a proof.
    // _kzgData: [y(32) | commitment(48) | proof(48)]
    function proveState(
        uint64 _batchIndex,
        bytes calldata _aggrProof,
        bytes calldata _kzgData
    ) external {
        // Check validity of proof
        require(_aggrProof.length > 0, "Invalid proof");

        // Check validity of KZG data
        require(_kzgData.length == 128, "Invalid KZG data");

        // uint64 layer2ChainId = IRollup(rollup).layer2ChainId();
        uint64 layer2ChainId = uint64(53077);

        // Extract commitment
        bytes memory _commitment = _kzgData[32:80];

        console.log("_commitment:");
        console.logBytes(_commitment);

        // Compute xBytes
        bytes memory _xBytes = computeXBytes(_batchIndex, _commitment);
        // console.log("_xBytes:");
        // console.logBytes(_xBytes);


        // Create input for verification
        bytes memory _input = abi.encodePacked(
            committedBatchStores[_batchIndex].blobVersionedHash,
            _xBytes,
            _kzgData
        );
        (bool success, bytes memory data) = address(0x0A).staticcall(_input);
        require(success, "failed to call point evaluation precompile");
        (, uint256 result) = abi.decode(data, (uint256, uint256));
        require(result == BLS_MODULUS, "precompile unexpected output");




        bytes32 testPI = 0xe698da76711a736ca1d780da214aa283e15465e079c1f2dfaca3a1e7f51cf36e;
        bytes32 publicInputHash = computePublicInputHash(
            _batchIndex,
            _xBytes,
            _kzgData[0:32]
        );
        console.log("publicInputHash:");
        console.logBytes32(publicInputHash);

        console.log("expected_publicInputHash:");
        console.logBytes32(testPI);

        // Verify batch
        IZkEvmVerifier(zkevm_verifier).verify(_aggrProof, publicInputHash);

        // Record defender win
        // challenges[_batchIndex].finished = true;
    }

    function computeXBytes(
        uint64 _batchIndex,
        bytes memory commitment
    ) private view returns (bytes memory) {
        bytes memory xBytes = abi.encode(
            keccak256(
                abi.encodePacked(
                    commitment,
                    committedBatchStores[_batchIndex].dataHash
                )
            )
        );
        xBytes[0] = 0x0; // make sure x < BLS_MODULUS
        return xBytes;
    }

    function computePublicInputHash(
        uint64 _batchIndex,
        bytes memory _xBytes,
        bytes memory _yBytes
    ) private view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    uint64(53077),
                    committedBatchStores[_batchIndex].prevStateRoot,
                    committedBatchStores[_batchIndex].postStateRoot,
                    committedBatchStores[_batchIndex].withdrawalRoot,
                    committedBatchStores[_batchIndex].dataHash,
                    splitUint256(_xBytes),
                    splitUint256(_yBytes)
                )
            );
    }

    function splitUint256(
        bytes memory _combined
    ) public pure returns (bytes memory) {
        require(_combined.length == 32, "Input length must be 32 bytes");

        console.log("point_bytes:");
        console.logBytes(_combined);

        uint256 combinedUint;
        assembly {
            combinedUint := mload(add(_combined, 0x20))
        }
        console.log("combinedUint:");
        console.logUint(combinedUint);

        uint256 part1;
        uint256 part2;
        uint256 part3;

        // Extract the three parts
        part1 = reverseBytes(combinedUint & ((1 << 88) - 1)); // Mask the lowest 88 bits and reverse bytes
        console.log("part1:");
        console.logUint(part1);
        part2 = reverseBytes((combinedUint >> 88) & ((1 << 88) - 1)); // Shift right by 88 bits, mask the next 88 bits, and reverse bytes
        console.log("part2:");
        console.logUint(part2);
        part3 = reverseBytes((combinedUint >> 176) & ((1 << 87) - 1)); // Shift right by 176 bits, mask the next 87 bits, and reverse bytes
        console.log("part3:");
        console.logUint(part3);

        bytes memory result = new bytes(96);
        assembly {
            // Store the parts in the result bytes
            mstore(add(result, 0x20), part1)
            mstore(add(result, 0x40), part2)
            mstore(add(result, 0x60), part3)
        }

        console.log("splitUint256_result:");
        console.logBytes(result);
        return result;
    }

    function reverseBytes(uint256 input) private pure returns (uint256 v) {
        v = input;

        // swap bytes
        v =
            ((v &
                0xFF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00) >>
                8) |
            ((v &
                0x00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF) <<
                8);

        // swap 2-byte long pairs
        v =
            ((v &
                0xFFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000) >>
                16) |
            ((v &
                0x0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF) <<
                16);

        // swap 4-byte long pairs
        v =
            ((v &
                0xFFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000) >>
                32) |
            ((v &
                0x00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF) <<
                32);

        // swap 8-byte long pairs
        v =
            ((v &
                0xFFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF0000000000000000) >>
                64) |
            ((v &
                0x0000000000000000FFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF) <<
                64);

        // swap 16-byte long pairs
        v = (v >> 128) | (v << 128);
    }

    function reverseBytes2(uint256 input) public pure returns (uint256) {
        uint256 reversed = 0;
        for (uint256 i = 0; i < 32; i++) {
            reversed = (reversed << 8) | ((input >> (i * 8)) & 0xFF);
        }
        return reversed;
    }

    function reverseBytesA(
        bytes memory input
    ) public pure returns (bytes memory) {
        bytes memory reversed = new bytes(input.length);
        for (uint256 i = 0; i < input.length; i++) {
            reversed[i] = input[input.length - 1 - i];
        }
        console.log("reverseBytesA:");
        console.logBytes(reversed);
        return reversed;
    }

    function reverseBytes1(
        uint256 input
    ) private pure returns (uint256 output) {
        uint256 len = 32; // 256 bits
        assembly {
            let reversed := mload(0x40) // Allocate memory for output
            for {
                let i := 0
            } lt(i, len) {
                i := add(i, 1)
            } {
                let byteIndex := sub(sub(len, 1), i) // Calculate byte index in little endian
                let byteValue := byte(byteIndex, input) // Get byte from input
                mstore8(add(reversed, i), byteValue) // Store byte in reversed order
            }
            output := reversed
        }
    }

    /// @notice Update the address rollup contract.
    function updateRollup(address _rollup) external onlyOwner {
        rollup = _rollup;
    }

    /// @notice Update the address verifier contract.
    function updateVerifier(address _verifier) external onlyOwner {
        zkevm_verifier = _verifier;
    }

    function batchInChallenge(uint256 batchIndex) public view returns (bool) {
        return
            challenges[batchIndex].challenger != address(0) &&
            !challenges[batchIndex].finished;
    }

    function isBatchFinalized(
        uint256 _batchIndex
    ) external pure returns (bool) {
        require(_batchIndex > 0, "invalid batchIndex");
        return false;
    }
}
