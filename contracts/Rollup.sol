// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

contract Rollup {
    struct BatchStore {
        bytes32 batchHash;
        uint256 originTimestamp;
        bytes32 prevStateRoot;
        bytes32 postStateRoot;
        bytes32 withdrawalRoot;
        bytes32 dataHash;
        address sequencer;
        uint256 l1MessagePopped;
        uint256 totalL1MessagePopped;
        bytes skippedL1MessageBitmap;
        uint256 blockNumber;
    }

    mapping(uint256 => BatchStore) public committedBatchStores;
}
