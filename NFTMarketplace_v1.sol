// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// counters depracted
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "hardhat/console.sol";

contract NFTMarketplace is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    Counters.Counter private _itemsSold;

    uint256 listingPrice = 0.25 ether;
    uint256 transferFee = 2;
    uint256 public maxSupply = 1000;
    uint256 private currentBatchNumber = 1;

    address payable immutable owner;

    mapping(uint256 => MarketItem) private idToMarketItem;

    mapping(uint256 => uint256) private idToRoyaltyPercentage;

    mapping(uint256 => uint256) private idToBatchSpecificId;

    mapping(uint256 => uint256) private tokenToBatchSpecificId;

    struct MarketItem {
        uint256 tokenId;
        address payable seller;
        address payable owner;
        address creator;
        uint256 price;
        uint256 royaltyPercentage;
        bool sold;
        uint batchNumber;
        uint256 batchSpecificId; // New field for batch-specific ID
    }

    event NewTokensCreated(
        uint256[] tokenIds,
        address indexed creator,
        uint256 quantity,
        uint256 royaltyPercentage,
        uint256 batchNumber,
        uint256[] batchSpecificIds // Add batch specific IDs to the event
    );

    event MarketItemCreated(
        uint256 indexed tokenId,
        address seller,
        address owner,
        address creator, // Add the creator field
        uint256 price,
        uint256 royaltyPercentage, // Add the royaltyPercentage field
        bool sold,
        uint batchNumber
    );

    event FeesUpdated(uint256 newListingPrice, uint256 NewTransferFee);

    event RoyaltyPaid(uint256 tokenId, address creator, uint256 royaltyAmount);

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "only owner of the marketplace can change the listing price"
        );
        _;
    }

    // Modifier to prevent reentrant calls
    bool private _locked;
    modifier nonReentrant() {
        require(!_locked, "Reentrant call");
        _locked = true;
        _;
        _locked = false;
    }

    modifier withinMaxSupply() {
        require(_tokenIds.current() + 1 <= maxSupply, "Maximum supply reached");
        _;
    }

    constructor() ERC721("Greatest Show On Earth", "GSOE") {
        owner = payable(msg.sender);
        idToBatchSpecificId[1] = 1;
    }

    /* Updates the listing price of the contract */
    function updateFees(
        uint256 _listingPrice,
        uint256 _transferFee
    ) external onlyOwner {
        // Validate fees
        require(
            owner == msg.sender,
            "Only marketplace owner can update listing fees."
        );

        // Update state variables
        listingPrice = _listingPrice;
        transferFee = _transferFee;

        // Emit single event
        emit FeesUpdated(listingPrice, transferFee);
    }

    function getFees() external view returns (uint256, uint256) {
        return (listingPrice, transferFee);
    }

    function updateMaxSupply(uint256 newMaxSupply) external onlyOwner {
        maxSupply = newMaxSupply;
    }

    // Function to get the batch number of a token
    function getBatchNumber(uint256 tokenId) public view returns (uint256) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");

        MarketItem storage marketItem = idToMarketItem[tokenId];
        require(marketItem.tokenId == tokenId, "Token not found in market");

        return marketItem.batchNumber;
    }
    function getBatchSpecificId(uint256 tokenId) public view returns (uint256) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        return tokenToBatchSpecificId[tokenId];
    }

    // Modify token creation function to store creator and royalty percentage
    function createToken(
        string memory tokenURI,
        uint256 price,
        uint256 royaltyPercentage,
        uint256 quantity
    ) public payable nonReentrant withinMaxSupply returns (uint256[] memory) {
        require(royaltyPercentage <= 100, "Royalty percentage must be <= 100");
        require(quantity >= 1, "Quantity must be at least 1");

        uint256[] memory newTokenIds = new uint256[](quantity);
        uint256[] memory batchSpecificIds = new uint256[](quantity); // Create an array to store batch-specific IDs

        uint256 totalListingCost = listingPrice * quantity;
        require(msg.value >= totalListingCost, "Insufficient listing fee");

        for (uint256 i = 0; i < quantity; i++) {
            _tokenIds.increment();
            uint256 newTokenId = _tokenIds.current();
            uint256 batchSpecificId = i + 1; // Incrementing batch-specific ID

            _mint(msg.sender, newTokenId);
            _setTokenURI(newTokenId, tokenURI);
            idToRoyaltyPercentage[newTokenId] = royaltyPercentage;
            tokenToBatchSpecificId[newTokenId] = batchSpecificId; // Store batch-specific ID

            newTokenIds[i] = newTokenId; // Store the new token ID
            batchSpecificIds[i] = batchSpecificId; // Store the batch-specific ID
        }

        createMarketItem(newTokenIds, price, msg.sender); // Call createMarketItem with newTokenIds, price, and msg.sender

        emit NewTokensCreated(
            newTokenIds,
            msg.sender,
            quantity,
            royaltyPercentage,
            currentBatchNumber,
            batchSpecificIds
        );

        currentBatchNumber++; // Increment the batch number for the next batch

        return newTokenIds;
    }

    function createMarketItem(
        uint256[] memory tokenIds,
        uint256 price,
        address creator
    ) private {
        require(
            msg.value == listingPrice * tokenIds.length,
            "Price must be equal to listing price multiplied by quantity"
        );

        uint256 batchNumber = currentBatchNumber; // Store the current batch number

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            uint256 royaltyPercentage = idToRoyaltyPercentage[tokenId];
            uint256 batchSpecificId = tokenToBatchSpecificId[tokenId];
            idToMarketItem[tokenId] = MarketItem(
                tokenId,
                payable(msg.sender),
                payable(address(this)),
                creator,
                price,
                royaltyPercentage,
                false,
                batchNumber,
                batchSpecificId // Store the batch-specific ID
            );

            _transfer(msg.sender, address(this), tokenId);
            emit MarketItemCreated(
                tokenId,
                msg.sender,
                address(this),
                creator,
                price,
                royaltyPercentage,
                false,
                batchNumber
            );
        }

        // payable(owner).transfer(listingPrice * tokenIds.length);
    }

    function createMarketSale(uint256 tokenId) public payable nonReentrant {
        uint256 salePrice = idToMarketItem[tokenId].price;
        require(msg.value == salePrice, "Please submit the asking price");
        require(ownerOf(tokenId) == address(this), "Item is not for sale");

        address payable seller = idToMarketItem[tokenId].seller;
        address creator = idToMarketItem[tokenId].creator; // Retrieve creator's address
        uint256 royaltyPercentage = idToRoyaltyPercentage[tokenId]; // Retrieve royalty percentage

        uint256 feeAmount = (salePrice * transferFee) / 100;
        uint256 royaltyAmount = ((salePrice - feeAmount) * royaltyPercentage) /
            100;
        uint256 paymentToSeller = salePrice - feeAmount - royaltyAmount;

        idToMarketItem[tokenId].owner = payable(msg.sender);
        idToMarketItem[tokenId].sold = true;
        idToMarketItem[tokenId].seller = payable(address(0));
        _itemsSold.increment();
        _transfer(address(this), msg.sender, tokenId);

        seller.transfer(paymentToSeller);
        payable(creator).transfer(royaltyAmount); // Send royalty payment to the creator
        // {FeeAmount(transFerFee)} Retained
    }

    /* allows someone to resell a token they have purchased */
    function resellToken(
        uint256 tokenId,
        uint256 price
    ) public payable nonReentrant {
        require(
            idToMarketItem[tokenId].owner == msg.sender,
            "Only item owner can perform this operation"
        );
        require(
            msg.value == listingPrice,
            "Price must be equal to listing price"
        );
        idToMarketItem[tokenId].sold = false;
        idToMarketItem[tokenId].price = price;
        idToMarketItem[tokenId].seller = payable(msg.sender);
        idToMarketItem[tokenId].owner = payable(address(this));
        _itemsSold.decrement();

        _transfer(msg.sender, address(this), tokenId);

        // Transfer the listing price to the contract owner
        payable(owner).transfer(listingPrice);
    }

    function delistTokens(
        uint256[] calldata tokenIds
    ) external payable nonReentrant {
        uint256 totalListingPrice = (listingPrice * 2) * tokenIds.length;

        require(msg.value == totalListingPrice, "Delisting price");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];

            require(
                idToMarketItem[tokenId].seller == msg.sender,
                "Only item owner!!!"
            );

            idToMarketItem[tokenId].sold = true;
            idToMarketItem[tokenId].seller = payable(address(0));
            _itemsSold.increment();
            idToMarketItem[tokenId].owner = payable(msg.sender);

            _transfer(address(this), msg.sender, tokenId);
        }

        // Transfer ownership of all NFTs

        // Transfer total listing price in one call
        payable(owner).transfer(totalListingPrice);
    }

    /* Returns all unsold market items */
    function fetchMarketItems() public view returns (MarketItem[] memory) {
        uint256 itemCount = _tokenIds.current();
        uint256 unsoldItemCount = _tokenIds.current() - _itemsSold.current();
        uint256 currentIndex = 0;

        MarketItem[] memory items = new MarketItem[](unsoldItemCount);
        for (uint256 i = 0; i < itemCount; i++) {
            if (idToMarketItem[i + 1].owner == address(this)) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    /* Returns only items that a user has purchased */
    function fetchMyNFTs() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _tokenIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    /* Returns only items a user has listed */
    function fetchItemsListed() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _tokenIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    // Function to withdraw funds by the contract owner
    function clearCache(uint256 amount) external onlyOwner {
        require(amount <= address(this).balance, "0 bal");
        owner.transfer(amount);
    }
}
