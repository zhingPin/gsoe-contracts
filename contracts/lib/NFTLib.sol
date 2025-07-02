// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library NFTLib {
    struct TokenMetadata {
        uint256 batchNumber;
        uint256 batchSpecificId;
        uint256 royaltyPercentage;
        address creator;
        uint256 createdAt;
    }
}
