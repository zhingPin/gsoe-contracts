// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MarketplaceCore} from "./MarketplaceCore.sol";
import {INFT} from "./interfaces/INFT.sol";

contract NFTMarketMinter is MarketplaceCore {
    event BatchMintAndListed(
        address indexed minter,
        uint256[] tokenIds,
        uint256 price,
        uint256 timestamp
    );

    constructor(address nftAddress) MarketplaceCore(nftAddress) {}
    function mintAndList(
        string memory tokenURI,
        uint256 price,
        uint256 royaltyPercentage,
        uint256 quantity
    ) external payable nonReentrant whenNotPaused {
        require(bytes(tokenURI).length > 0, "tokenURI must not be empty");
        require(quantity > 0, "Quantity must be at least 1");
        require(price > 0, "Price must be > 0");

        uint256 totalListingFee = listingPrice * quantity;
        uint256 totalMintFee = nftContract.mintFee() * quantity;
        uint256 totalFee = totalListingFee + totalMintFee;

        require(msg.value == totalFee, "Incorrect total fee");

        // Mint directly to marketplace, but set creator as msg.sender
        uint256[] memory newTokenIds = nftContract.mintBatch{
            value: totalMintFee
        }(address(this), msg.sender, tokenURI, quantity, royaltyPercentage);

        // No need to transfer tokens, marketplace owns them already

        _createMarketItems(newTokenIds, price, msg.sender);

        emit BatchMintAndListed(
            msg.sender,
            newTokenIds,
            price,
            block.timestamp
        );
    }
}
