// contracts/GLDToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;
import "@openzeppelin/contracts/access/Ownable.sol";
import {Rollup} from "./Rollup.sol";
import {IRollupVerifier} from "./IRollupVerifier.sol";

/// @title Rollup
/// @notice This contract maintains data for rollup.
contract ShadowRollup is Ownable {
    address public rollup;
    address public verifier;

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

    constructor(address _rollup, address _verifier) {
        rollup = _rollup;
        verifier = _verifier;
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
    function proveState(
        uint64 _batchIndex,
        bytes calldata _aggrProof
    ) external {
        // check proof
        require(_aggrProof.length > 0, "invalid proof");

        (
            ,
            ,
            bytes32 prevStateRoot,
            bytes32 postStateRoot,
            bytes32 withdrawalRoot,
            bytes32 dataHash,
            ,
            ,
            ,
            ,

        ) = Rollup(rollup).committedBatchStores(_batchIndex);

        // compute public input hash
        bytes32 _publicInputHash = keccak256(
            abi.encodePacked(
                uint64(2710),
                prevStateRoot,
                postStateRoot,
                withdrawalRoot,
                dataHash
            )
        );

        // verify batch
        IRollupVerifier(verifier).verifyAggregateProof(
            _batchIndex,
            _aggrProof,
            _publicInputHash
        );
        challenges[_batchIndex].finished = true;
    }

    /// @notice Update the address rollup contract.
    function updateRollup(address _rollup) external onlyOwner {
        rollup = _rollup;
    }

    /// @notice Update the address verifier contract.
    function updateVerifier(address _verifier) external onlyOwner {
        verifier = _verifier;
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
