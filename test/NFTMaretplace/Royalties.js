const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NFTMarketplace Royalties", function () {
    let nftContract, marketplace;
    let owner, seller, creator, buyer;
    const listingPrice = ethers.utils.parseEther("0.025");
    const nftPrice = ethers.utils.parseEther("1");

    beforeEach(async () => {
        [owner, seller, creator, buyer] = await ethers.getSigners();

        const NFTMock = await ethers.getContractFactory("GSOEToken");
        nftContract = await NFTMock.deploy();
        await nftContract.deployed();

        const Marketplace = await ethers.getContractFactory("NFTMarketplace");
        marketplace = await Marketplace.deploy(nftContract.address);
        await marketplace.deployed();

        // Grant MINTER_ROLE to marketplace
        const MINTER_ROLE = ethers.utils.id("MINTER_ROLE");
        await nftContract.grantRole(MINTER_ROLE, marketplace.address);
    });


    it("should distribute royalty, seller proceeds, and marketplace fees correctly", async function () {
        // Mint batch from seller, royalty 10%
        const royaltyPercent = 10;

        // Simulate mintBatch by seller through marketplace
        await marketplace.connect(seller).mintAndList(
            "ipfs://token-uri",
            nftPrice,
            royaltyPercent,
            1,
            { value: listingPrice }
        );

        // Fetch newly minted item
        const items = await marketplace.fetchMarketItems();
        expect(items.length).to.equal(1);
        const listingId = items[0].listingId;

        // Check initial pending withdrawals
        expect(await marketplace.pendingWithdrawals(seller.address)).to.equal(0);
        expect(await marketplace.pendingWithdrawals(owner.address)).to.equal(0);
        expect(await marketplace.pendingWithdrawals(creator.address)).to.equal(0);

        // Buyer buys the NFT, sending nftPrice (1 ETH)
        await marketplace.connect(buyer).buyItem(listingId, { value: nftPrice });

        // Calculate expected values
        const transferFeePercent = await marketplace.transferFee(); // 2%
        const fee = nftPrice.mul(transferFeePercent).div(100);
        const royalty = nftPrice.mul(royaltyPercent).div(100);
        const sellerProceeds = nftPrice.sub(fee).sub(royalty);

        // Get MarketItem to check creator address
        const item = await marketplace.idToMarketItem(listingId);

        // Check pendingWithdrawals for each party
        const sellerPending = await marketplace.pendingWithdrawals(seller.address);
        const ownerPending = await marketplace.pendingWithdrawals(owner.address);
        const creatorPending = await marketplace.pendingWithdrawals(item.creator);

        expect(sellerPending).to.equal(sellerProceeds);
        expect(ownerPending).to.equal(fee);
        expect(creatorPending).to.equal(royalty);

        // Withdraw as seller
        const sellerBalanceBefore = await ethers.provider.getBalance(seller.address);
        const tx = await marketplace.connect(seller).withdraw();
        const receipt = await tx.wait();
        const gasUsed = receipt.gasUsed.mul(receipt.effectiveGasPrice);
        const sellerBalanceAfter = await ethers.provider.getBalance(seller.address);

        expect(sellerBalanceAfter).to.be.closeTo(
            sellerBalanceBefore.add(sellerPending).sub(gasUsed),
            ethers.utils.parseEther("0.001")
        );
    });
});
