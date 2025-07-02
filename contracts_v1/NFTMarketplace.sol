// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {INFT} from "./INFT.sol";

contract NFTMarketplace is ReentrancyGuard, Pausable, Ownable, IERC721Receiver {
    INFT public nftContract;
    uint256 public newListingId;

    uint256 public listingPrice = 0.025 ether;
    uint256 public transferFee = 2;
    uint256 public totalMarketplaceEarnings;
    uint256[] public marketListingIds;

    struct MarketItem {
        uint256 listingId;
        uint256 tokenId;
        address payable seller;
        address payable creator;
        address owner;
        uint256 price;
        uint256 royaltyPercentage;
        bool sold;
        uint256 batchNumber;
        uint256 batchSpecificId;
    }

    event MarketItemCreated(
        uint256 indexed listingId,
        uint256 indexed tokenId,
        address indexed seller,
        uint256 price
    );
    event MarketItemSold(
        uint256 indexed listingId,
        uint256 indexed tokenId,
        address indexed buyer,
        uint256 price
    );
    event MarketItemDelisted(
        uint256 indexed listingId,
        uint256 indexed tokenId,
        address indexed seller
    );

    event Withdraw(address indexed user, uint256 amount);

    mapping(uint256 => MarketItem) public idToMarketItem;
    mapping(uint256 => uint256[]) public tokenIdToListings;
    mapping(address => uint256) public pendingWithdrawals;

    constructor(address nftAddress) Ownable(msg.sender) {
        nftContract = INFT(nftAddress);
    }

    /// @notice Handle the receipt of an NFT
    /// @dev The ERC721 smart contract calls this function on the recipient after a safeTransfer.
    /// It must return its Solidity selector to confirm the token transfer.
    /// If any other value is returned or the interface is not implemented, the transfer will be reverted.
    function onERC721Received(
        address /*operator*/,
        address /*from*/,
        uint256 /*tokenId*/,
        bytes calldata /*data*/
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
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
            msg.sender, // ← This is the creator
            tokenURI,
            quantity,
            royaltyPercentage
        );

        _createMarketItems(newTokenIds, price, msg.sender);
    }

    function listItem(
        uint256 tokenId,
        uint256 price
    ) external payable nonReentrant whenNotPaused {
        require(price > 0, "Price must be > 0");
        require(msg.value == listingPrice, "Listing fee required");

        nftContract.safeTransferFrom(msg.sender, address(this), tokenId);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        _createMarketItems(tokenIds, price, msg.sender);
    }

    function _createMarketItems(
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

            newListingId++;
            MarketItem memory item = MarketItem(
                newListingId,
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

            idToMarketItem[newListingId] = item;
            tokenIdToListings[tokenId].push(newListingId);
            marketListingIds.push(newListingId);

            emit MarketItemCreated(newListingId, tokenId, seller, price);
        }
    }

    function buyItem(
        uint256 listingId
    ) external payable nonReentrant whenNotPaused {
        MarketItem storage item = idToMarketItem[listingId];
        require(!item.sold, "Item already sold");
        require(msg.value == item.price, "Wrong ETH amount");

        uint256 fee = (item.price * transferFee) / 100;
        uint256 royaltyAmount = (item.price * item.royaltyPercentage) / 100;
        uint256 sellerProceeds = item.price - fee - royaltyAmount;
        totalMarketplaceEarnings += fee;

        // item.seller.transfer(sellerProceeds);
        // payable(owner()).transfer(fee);
        // item.creator.transfer(royaltyAmount);
        pendingWithdrawals[item.seller] += sellerProceeds;
        pendingWithdrawals[item.creator] += royaltyAmount;
        pendingWithdrawals[owner()] += fee;

        item.sold = true;
        item.owner = msg.sender;

        nftContract.safeTransferFrom(address(this), msg.sender, item.tokenId);

        emit MarketItemSold(listingId, item.tokenId, msg.sender, item.price);
    }

    function delistItem(uint256 listingId) external nonReentrant whenNotPaused {
        MarketItem storage item = idToMarketItem[listingId];
        require(item.seller == msg.sender, "Only seller can delist");
        require(!item.sold, "Already sold");

        nftContract.safeTransferFrom(address(this), msg.sender, item.tokenId);
        delete idToMarketItem[listingId];

        emit MarketItemDelisted(listingId, item.tokenId, msg.sender);
    }

    function fetchMarketItems() public view returns (MarketItem[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < marketListingIds.length; i++) {
            if (!idToMarketItem[marketListingIds[i]].sold) {
                count++;
            }
        }

        MarketItem[] memory items = new MarketItem[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < marketListingIds.length; i++) {
            uint256 id = marketListingIds[i];
            if (!idToMarketItem[id].sold) {
                items[index] = idToMarketItem[id];
                index++;
            }
        }
        return items;
    }

    function fetchMyNFTs() public view returns (MarketItem[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < marketListingIds.length; i++) {
            uint256 id = marketListingIds[i];
            if (
                idToMarketItem[id].sold &&
                nftContract.ownerOf(idToMarketItem[id].tokenId) == msg.sender
            ) {
                count++;
            }
        }

        MarketItem[] memory items = new MarketItem[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < marketListingIds.length; i++) {
            uint256 id = marketListingIds[i];
            if (
                idToMarketItem[id].sold &&
                nftContract.ownerOf(idToMarketItem[id].tokenId) == msg.sender
            ) {
                items[index] = idToMarketItem[id];
                index++;
            }
        }
        return items;
    }

    function fetchItemsListed() public view returns (MarketItem[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < marketListingIds.length; i++) {
            if (idToMarketItem[marketListingIds[i]].seller == msg.sender) {
                count++;
            }
        }

        MarketItem[] memory items = new MarketItem[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < marketListingIds.length; i++) {
            uint256 id = marketListingIds[i];
            if (idToMarketItem[id].seller == msg.sender) {
                items[index] = idToMarketItem[id];
                index++;
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

    function getNftOwner(uint256 tokenId) public view returns (address) {
        return nftContract.ownerOf(tokenId);
    }

    function updateFees(
        uint256 _listingPrice,
        uint256 _transferFee
    ) external onlyOwner {
        listingPrice = _listingPrice;
        transferFee = _transferFee;
    }

    function getMarketplaceEarnings() external view returns (uint256) {
        return totalMarketplaceEarnings;
    }

    function withdraw() external {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "Nothing to withdraw");

        pendingWithdrawals[msg.sender] = 0;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Withdraw failed");

        emit Withdraw(msg.sender, amount);
    }
}
