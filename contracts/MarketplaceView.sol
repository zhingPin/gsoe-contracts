// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {INFT} from "./interfaces/INFT.sol";
import {MarketplaceLib} from "./lib/MarketplaceLib.sol";
import {IMarketplaceCore} from "./interfaces/IMarketplaceCore.sol";

contract MarketplaceView {
    IMarketplaceCore public marketplace;
    INFT public nft;

    constructor(address marketplaceAddress) {
        marketplace = IMarketplaceCore(marketplaceAddress);
        nft = INFT(marketplace.nftContract());
    }

    function fetchMarketItems()
        public
        view
        returns (MarketplaceLib.MarketItem[] memory)
    {
        return marketplace.getActiveMarketItems();
    }

    function fetchMyNFTs()
        public
        view
        returns (MarketplaceLib.MarketItem[] memory)
    {
        return marketplace.getSoldItemsOwnedBy(msg.sender);
    }

    function fetchItemsListed()
        public
        view
        returns (MarketplaceLib.MarketItem[] memory)
    {
        return marketplace.getItemsListedBy(msg.sender);
    }

    function getNftOwner(uint256 tokenId) public view returns (address) {
        return nft.ownerOf(tokenId);
    }

    function getFees() external view returns (uint256, uint256) {
        return (marketplace.listingPrice(), marketplace.transferFee());
    }

    function getMarketplaceEarnings() external view returns (uint256) {
        return marketplace.totalMarketplaceEarnings();
    }
}
