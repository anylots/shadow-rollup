// contracts/GLDToken.sol
// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;
import "@openzeppelin/contracts/access/Ownable.sol";
import {IRollup} from "./IRollup.sol";
import {IZkEvmVerifier} from "./libs/IZkEvmVerifier.sol";

/// @title ShadowRollup
/// @notice This contract maintains data for shadow rollup.
contract ShadowRollup is Ownable {
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
    /// @param batchData The BatchData struct
    /// @param version The sequencer version
    /// @param sequencerIndex The sequencers index
    /// @param signature The BLS signature
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

        uint64 layer2ChainId = IRollup(rollup).layer2ChainId();

        // Compute public input hash
        bytes32 _publicInputHash = keccak256(
            abi.encodePacked(
                layer2ChainId,
                committedBatchStores[_batchIndex].prevStateRoot,
                committedBatchStores[_batchIndex].postStateRoot,
                committedBatchStores[_batchIndex].withdrawalRoot,
                committedBatchStores[_batchIndex].dataHash
            )
        );

        // Extract commitment
        bytes memory _commitment = _kzgData[32:80];

        // Compute xBytes
        bytes memory _xBytes = abi.encode(
            keccak256(
                abi.encodePacked(
                    _commitment,
                    committedBatchStores[_batchIndex].dataHash
                )
            )
        );
        // make sure x < BLS_MODULUS
        _xBytes[0] = 0x0;

        // Create input for verification
        bytes memory _input = abi.encode(
            committedBatchStores[_batchIndex].blobVersionedHash,
            _xBytes,
            _kzgData
        );

        bool ret;
        bytes memory _output;
        assembly {
            ret := staticcall(gas(), 0x0a, _input, 0xc0, _output, 0x40)
        }
        require(ret, "verify 4844-proof failed");

        // Verify batch
        bytes32 _newPublicInputHash = keccak256(
            abi.encodePacked(_publicInputHash, _xBytes, _kzgData[0:32])
        );
        IZkEvmVerifier(zkevm_verifier).verify(_aggrProof, _newPublicInputHash);

        // Record defender win
        challenges[_batchIndex].finished = true;
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
