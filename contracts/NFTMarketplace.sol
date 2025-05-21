// NFTMarketplace.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "./INFT.sol";

contract NFTMarketplace is ReentrancyGuard, Pausable, Ownable {
    INFT public nftContract;
    uint256 private _itemsSold;
    uint256[] public marketTokenIds;

    uint256 public listingPrice = 0.025 ether;
    uint256 public transferFee = 2;

    struct MarketItem {
        uint256 tokenId;
        address payable seller;
        address payable creator; // New
        address owner;
        uint256 price;
        uint256 royaltyPercentage; // New
        bool sold;
        uint256 batchNumber; // New: batch number from NFT contract
        uint256 batchSpecificId; // New: batch-specific ID
    }

    event MarketItemCreated(
        uint256 indexed tokenId,
        address indexed seller,
        uint256 price
    );
    event MarketItemSold(
        uint256 indexed tokenId,
        address indexed buyer,
        uint256 price
    );

    event MarketItemDelisted(uint256 indexed tokenId, address indexed seller);

    mapping(uint256 => MarketItem) public idToMarketItem;

    constructor(address nftAddress) Ownable(msg.sender) {
        nftContract = INFT(nftAddress);
    }

    function mintAndList(
        string memory tokenURI,
        uint256 price,
        uint256 royaltyPercentage,
        uint256 quantity
    ) external payable nonReentrant whenNotPaused {
        require(quantity > 0, "Quantity must be at least 1");
        require(price > 0, "Price must be > 0");
        require(
            msg.value == listingPrice * quantity,
            "Incorrect total listing fee"
        );

        uint256[] memory newTokenIds = nftContract.mintBatch(
            address(this),
            tokenURI,
            quantity,
            royaltyPercentage
        );

        createMarketItem(newTokenIds, price, msg.sender);
    }

    function createMarketItem(
        uint256[] memory tokenIds,
        uint256 price,
        address seller
    ) private {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];

            (
                uint256 batchNumber,
                uint256 batchSpecificId,
                uint256 royaltyPercentage,
                address creator
            ) = nftContract.getTokenInfo(tokenId);

            idToMarketItem[tokenId] = MarketItem(
                tokenId,
                payable(seller),
                payable(creator),
                address(this),
                price,
                royaltyPercentage,
                false,
                batchNumber,
                batchSpecificId
            );

            marketTokenIds.push(tokenId);

            emit MarketItemCreated(tokenId, seller, price);
        }
    }

    function buyItem(
        uint256 tokenId
    ) external payable nonReentrant whenNotPaused {
        MarketItem storage item = idToMarketItem[tokenId];
        require(!item.sold, "Item already sold");
        require(msg.value == item.price, "Wrong price");

        uint256 fee = (item.price * transferFee) / 100;
        uint256 royaltyAmount = (item.price * item.royaltyPercentage) / 100; // use royaltyPercentage stored in item
        uint256 sellerProceeds = item.price - fee - royaltyAmount;

        // Pay the seller
        item.seller.transfer(sellerProceeds);

        // Pay the marketplace owner (fee)
        payable(owner()).transfer(fee);

        // Pay the creator the royalty
        payable(item.creator).transfer(royaltyAmount);

        item.sold = true;
        _itemsSold += 1;
        nftContract.safeTransferFrom(address(this), msg.sender, tokenId);

        emit MarketItemSold(tokenId, msg.sender, item.price);
    }

    function listItem(
        uint256 tokenId,
        uint256 price
    ) external payable nonReentrant whenNotPaused {
        require(price > 0, "Price must be > 0");
        require(msg.value == listingPrice, "Listing fee required");

        nftContract.safeTransferFrom(msg.sender, address(this), tokenId);

        // Correctly create a memory array of length 1
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        createMarketItem(tokenIds, price, msg.sender);
    }

    function delistItem(uint256 tokenId) external nonReentrant whenNotPaused {
        MarketItem storage item = idToMarketItem[tokenId];
        require(item.seller == msg.sender, "Not item owner");
        require(!item.sold, "Already sold");

        nftContract.safeTransferFrom(address(this), msg.sender, tokenId);
        delete idToMarketItem[tokenId];

        emit MarketItemDelisted(tokenId, msg.sender);
    }

    // Returns all unsold market items
    function fetchMarketItems() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = marketTokenIds.length;
        uint256 unsoldItemCount = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (!idToMarketItem[marketTokenIds[i]].sold) {
                unsoldItemCount++;
            }
        }

        MarketItem[] memory items = new MarketItem[](unsoldItemCount);
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            uint256 tokenId = marketTokenIds[i];
            if (!idToMarketItem[tokenId].sold) {
                items[currentIndex] = idToMarketItem[tokenId];
                currentIndex++;
            }
        }

        return items;
    }

    // Returns only items that the caller has purchased
    function fetchMyNFTs() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = marketTokenIds.length;
        uint256 itemCount = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            uint256 tokenId = marketTokenIds[i];
            if (
                idToMarketItem[tokenId].sold &&
                nftContract.ownerOf(tokenId) == msg.sender
            ) {
                itemCount++;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            uint256 tokenId = marketTokenIds[i];
            if (
                idToMarketItem[tokenId].sold &&
                nftContract.ownerOf(tokenId) == msg.sender
            ) {
                items[currentIndex] = idToMarketItem[tokenId];
                currentIndex++;
            }
        }

        return items;
    }

    // Returns only items listed by the caller
    function fetchItemsListed() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = marketTokenIds.length;
        uint256 itemCount = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            uint256 tokenId = marketTokenIds[i];
            if (idToMarketItem[tokenId].seller == msg.sender) {
                itemCount++;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            uint256 tokenId = marketTokenIds[i];
            if (idToMarketItem[tokenId].seller == msg.sender) {
                items[currentIndex] = idToMarketItem[tokenId];
                currentIndex++;
            }
        }

        return items;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function getFees() external view returns (uint256, uint256) {
        return (listingPrice, transferFee);
    }

    function updateFees(
        uint256 _listingPrice,
        uint256 _transferFee
    ) external onlyOwner {
        listingPrice = _listingPrice;
        transferFee = _transferFee;
    }
}
