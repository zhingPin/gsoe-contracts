const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MarketplaceView", function () {
    let gsoeToken, marketplaceCore, nftContract, marketplaceView;
    let owner, seller, buyer;
    let tokenId1, tokenId2, price;

    beforeEach(async () => {
        [owner, seller, buyer] = await ethers.getSigners();

        const GSOEToken = await ethers.getContractFactory("GSOEToken");
        gsoeToken = await GSOEToken.deploy();
        await gsoeToken.deployed();

        // Deploy NFTMarketMinter (inherits MarketplaceCore)
        const NFTMarketMinter = await ethers.getContractFactory("NFTMarketMinter");
        marketplaceCore = await NFTMarketMinter.deploy(gsoeToken.address);
        await marketplaceCore.deployed();

        // Grant MINTER_ROLE to marketplaceCore if needed (check your contract)
        const MINTER_ROLE = await gsoeToken.MINTER_ROLE();
        await gsoeToken.grantRole(MINTER_ROLE, marketplaceCore.address);

        // Get NFT contract from marketplaceCore
        nftContract = await ethers.getContractAt("INFT", await marketplaceCore.nftContract());

        // Deploy MarketplaceView pointing to marketplaceCore
        const MarketplaceView = await ethers.getContractFactory("MarketplaceView");
        marketplaceView = await MarketplaceView.deploy(marketplaceCore.address);
        await marketplaceView.deployed();

        price = ethers.utils.parseEther("1");

        // Calculate total fees for mintAndList
        const listingPrice = await marketplaceCore.listingPrice();
        const mintFee = await nftContract.mintFee();
        const quantity = 2;
        const totalFee = listingPrice.mul(quantity).add(mintFee.mul(quantity));

        // Mint and list NFTs via NFTMarketMinter
        const tx = await marketplaceCore.connect(seller).mintAndList(
            "ipfs://tokenURI",
            price,
            10,          // royaltyPercentage
            quantity,
            { value: totalFee }
        );
        await tx.wait();

        tokenId1 = 1;
        tokenId2 = 2;

        // Buyer buys tokenId1
        await marketplaceCore.connect(buyer).buyItem(tokenId1, { value: price });
    });


    it("getNftOwner returns the correct owner", async () => {
        const ownerOfToken1 = await marketplaceView.getNftOwner(tokenId1);
        expect(ownerOfToken1).to.equal(buyer.address);
    });

    it("getFees returns listing price and transfer fee", async () => {
        const [listingPrice, transferFee] = await marketplaceView.getFees();
        expect(listingPrice).to.equal(await marketplaceCore.listingPrice());
        expect(transferFee).to.equal(await marketplaceCore.transferFee());
    });

    it("getMarketplaceEarnings returns total earnings", async () => {
        const earnings = await marketplaceView.getMarketplaceEarnings();
        expect(earnings).to.equal(await marketplaceCore.totalMarketplaceEarnings());
    });

    it("fetchMarketItems returns only unsold items", async () => {
        try {
            const items = await marketplaceView.fetchMarketItems();
            expect(items.length).to.equal(1);
            expect(items[0].tokenId).to.equal(tokenId2);
        } catch (error) {
            console.error("fetchMarketItems revert reason:", error);
            throw error; // rethrow so test still fails but you see reason
        }
    });

    it("fetchMyNFTs returns items owned by caller", async () => {
        const buyerItems = await marketplaceView.connect(buyer).fetchMyNFTs();
        expect(buyerItems.length).to.equal(1);
        expect(buyerItems[0].tokenId).to.equal(tokenId1);
    });

    it("fetchItemsListed returns all items listed by caller", async () => {
        const sellerItems = await marketplaceView.connect(seller).fetchItemsListed();
        expect(sellerItems.length).to.equal(2);
    });



});
