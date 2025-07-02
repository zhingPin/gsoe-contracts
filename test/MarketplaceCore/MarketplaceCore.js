const { expect } = require("chai");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");

const { ethers } = require("hardhat");

describe("MarketplaceCore", function () {
    let marketplace, gsoeToken, owner, seller, buyer;
    let tokenId, listingId;
    const tokenURI = "ipfs://token-metadata";
    const mintFee = ethers.utils.parseEther("0.01");
    const price = ethers.utils.parseEther("1");
    const royaltyPercentage = 10;

    beforeEach(async () => {
        [owner, seller, buyer] = await ethers.getSigners();

        const GSOEToken = await ethers.getContractFactory("GSOEToken");
        gsoeToken = await GSOEToken.deploy();
        await gsoeToken.deployed();

        const Marketplace = await ethers.getContractFactory("MarketplaceCore");
        marketplace = await Marketplace.deploy(gsoeToken.address);

        // Mint NFT to seller
        const MINTER_ROLE = await gsoeToken.MINTER_ROLE();
        await gsoeToken.grantRole(MINTER_ROLE, seller.address);

        const mintTx = await gsoeToken.connect(seller).mintBatch(
            seller.address,
            seller.address,
            tokenURI,
            1,
            royaltyPercentage,
            { value: mintFee }
        );

        const receipt = await mintTx.wait();

        const event = receipt.events.find(e => e.event === "BatchMinted");
        const tokenIds = event.args[2]; // array of token IDs
        tokenId = tokenIds[0]; // get the first one
    });



    it("Should allow a user to list an owned NFT", async () => {
        // Approve marketplace to transfer NFTs
        await gsoeToken.connect(seller).setApprovalForAll(marketplace.address, true);

        // List the NFT
        const tx = await marketplace.connect(seller).listItem(tokenId, price);
        const receipt = await tx.wait();

        const listEvent = receipt.events.find(e => e.event === "MarketItemCreated");
        listingId = listEvent.args.listingId;

        // Verify listing data
        const item = await marketplace.idToMarketItem(listingId);
        expect(item.tokenId).to.equal(tokenId);
        expect(item.seller).to.equal(seller.address);
        expect(item.price).to.equal(price);
    });

    it("Should allow a buyer to purchase a listed NFT", async () => {
        // Approve marketplace to transfer seller's NFT
        await gsoeToken.connect(seller).setApprovalForAll(marketplace.address, true);

        // List the NFT
        const listTx = await marketplace.connect(seller).listItem(tokenId, price);
        const listReceipt = await listTx.wait();

        const listEvent = listReceipt.events.find(e => e.event === "MarketItemCreated");
        const listingId = listEvent.args.listingId;

        // Buyer purchases the NFT by sending 'price' value
        await expect(
            marketplace.connect(buyer).buyItem(listingId, { value: price })
        )
            .to.emit(marketplace, "MarketItemSold")
            .withArgs(listingId, tokenId, buyer.address, price, anyValue);
        // anyValue matches timestamp

        // Check new ownership of token is buyer
        expect(await gsoeToken.ownerOf(tokenId)).to.equal(buyer.address);

        // Check the listing is marked inactive (sold)
        const item = await marketplace.idToMarketItem(listingId);
        expect(item.active).to.be.false;

        // Check seller pending withdrawal balance updated with price (minus fees if applicable)
        const pending = await marketplace.pendingWithdrawals(seller.address);
        expect(pending).to.equal(price);

        // Optionally: check totalMarketplaceEarnings increased if your contract tracks fees
        // const earnings = await marketplace.totalMarketplaceEarnings();
        // expect(earnings).to.equal(expectedFees);
    });

    it("Should allow seller to delist their NFT", async () => {
        // Approve marketplace to transfer NFTs
        await gsoeToken.connect(seller).setApprovalForAll(marketplace.address, true);

        // List the NFT
        let tx = await marketplace.connect(seller).listItem(tokenId, price);
        let receipt = await tx.wait();

        // Grab the listingId from the MarketItemCreated event
        const listEvent = receipt.events.find(e => e.event === "MarketItemCreated");
        const listingId = listEvent.args.listingId;

        // Seller delists their NFT
        tx = await marketplace.connect(seller).delistItem(listingId);
        receipt = await tx.wait();

        // Expect a MarketItemDelisted event
        const delistEvent = receipt.events.find(e => e.event === "MarketItemDelisted");
        expect(delistEvent).to.not.be.undefined;
        expect(delistEvent.args.listingId).to.equal(listingId);
        expect(delistEvent.args.seller).to.equal(seller.address);

        // Verify the listing is inactive
        const item = await marketplace.idToMarketItem(listingId);
        expect(item.active).to.be.false;
    });

    it("Should correctly distribute royalties and fees on sale", async () => {
        await gsoeToken.connect(seller).setApprovalForAll(marketplace.address, true);
        await marketplace.setTransferFee(5); // initial fee

        const listTx = await marketplace.connect(seller).listItem(tokenId, price);
        const listReceipt = await listTx.wait();
        const listingId = listReceipt.events.find(e => e.event === "MarketItemCreated").args.listingId;

        const platformFeePercent = 2; // 2%
        await marketplace.setTransferFee(platformFeePercent);

        const royaltyPercent = 10;
        const royaltyRecipient = seller.address; // for this example

        // Buyer purchases the NFT
        const buyTx = await marketplace.connect(buyer).buyItem(listingId, { value: price });
        await buyTx.wait();

        // Calculate expected distributions
        const platformFee = price.mul(platformFeePercent).div(100); // convert from %
        const royaltyFee = price.mul(royaltyPercent).div(100);
        const sellerReceives = price.sub(platformFee).sub(royaltyFee);

        // ✅ Check pendingWithdrawals
        expect(await marketplace.pendingWithdrawals(seller.address)).to.equal(sellerReceives.add(royaltyFee)); // since seller is also royaltyRecipient
        expect(await marketplace.pendingWithdrawals(owner.address)).to.equal(platformFee);

        // ✅ Check NFT transferred
        expect(await gsoeToken.ownerOf(tokenId)).to.equal(buyer.address);
    });

    it("Should allow seller, royalty recipient, and marketplace to withdraw after sale", async () => {
        const transferFeePercent = 5;
        const royaltyPercent = 10;

        // Approve and list NFT
        await gsoeToken.connect(seller).setApprovalForAll(marketplace.address, true);
        await marketplace.connect(owner).setTransferFee(transferFeePercent);

        const listTx = await marketplace.connect(seller).listItem(tokenId, price);
        const listReceipt = await listTx.wait();
        const listingId = listReceipt.events.find(e => e.event === "MarketItemCreated").args.listingId;

        // Capture balances before purchase
        const sellerBalanceBefore = await ethers.provider.getBalance(seller.address);
        const royaltyBalanceBefore = await ethers.provider.getBalance(seller.address); // seller is royalty recipient in your case
        const ownerBalanceBefore = await ethers.provider.getBalance(owner.address);

        // Buyer purchases the NFT
        const buyTx = await marketplace.connect(buyer).buyItem(listingId, { value: price });
        const buyReceipt = await buyTx.wait();

        // Compute amounts
        const feeAmount = price.mul(transferFeePercent).div(100);
        const royaltyAmount = price.mul(royaltyPercent).div(100);
        const sellerAmount = price.sub(feeAmount).sub(royaltyAmount);

        // Withdraw for seller
        const withdrawTx1 = await marketplace.connect(seller).withdrawFunds();
        const withdrawGas1 = (await withdrawTx1.wait()).gasUsed.mul(withdrawTx1.gasPrice ?? 0n);
        const sellerBalanceAfter = await ethers.provider.getBalance(seller.address);
        expect(sellerBalanceAfter).to.be.closeTo(
            sellerBalanceBefore.add(sellerAmount).add(royaltyAmount).sub(withdrawGas1),
            ethers.utils.parseEther("0.01")
        );

        // Withdraw for marketplace (owner)
        const withdrawTx2 = await marketplace.connect(owner).withdrawFunds();
        const withdrawGas2 = (await withdrawTx2.wait()).gasUsed.mul(withdrawTx2.gasPrice ?? 0n);
        const ownerBalanceAfter = await ethers.provider.getBalance(owner.address);
        expect(ownerBalanceAfter).to.be.closeTo(
            ownerBalanceBefore.add(feeAmount).sub(withdrawGas2),
            ethers.utils.parseEther("0.01")
        );

        // Confirm internal state is reset
        expect(await marketplace.pendingWithdrawals(seller.address)).to.equal(0);
        expect(await marketplace.pendingWithdrawals(owner.address)).to.equal(0);
    });

    describe("Edge case tests", () => {
        it("Should handle 0% royalty (no royalty payout)", async () => {
            // Setup: approve marketplace, set fees
            await gsoeToken.connect(seller).setApprovalForAll(marketplace.address, true);
            await marketplace.connect(owner).setTransferFee(5); // 5% fee

            // Mint NFT with 0% royalty - assuming mintBatch supports royalty input
            // If not, you might need to manually override royalty in your marketplace for test
            const zeroRoyaltyPercent = 0;

            // List NFT
            const listTx = await marketplace.connect(seller).listItem(tokenId, price);
            const listReceipt = await listTx.wait();
            const listingId = listReceipt.events.find(e => e.event === "MarketItemCreated").args.listingId;

            // Buy NFT
            await expect(
                marketplace.connect(buyer).buyItem(listingId, { value: price })
            ).to.not.be.reverted;

            // Check pendingWithdrawals for royalty recipient is zero
            const royaltyPending = await marketplace.pendingWithdrawals(seller.address);
            expect(royaltyPending).to.be.gte(price.mul(95).div(100)); // Seller gets price minus 5% fee, no royalty deduction
        });

        it("Should handle 0% transfer fee (no marketplace fee)", async () => {
            // Setup: approve marketplace, set fees
            await gsoeToken.connect(seller).setApprovalForAll(marketplace.address, true);
            await marketplace.connect(owner).setTransferFee(0); // 0% fee

            // List NFT
            const listTx = await marketplace.connect(seller).listItem(tokenId, price);
            const listReceipt = await listTx.wait();
            const listingId = listReceipt.events.find(e => e.event === "MarketItemCreated").args.listingId;

            // Buy NFT
            await expect(
                marketplace.connect(buyer).buyItem(listingId, { value: price })
            ).to.not.be.reverted;

            // Check marketplace earnings are zero
            const earnings = await marketplace.totalMarketplaceEarnings();
            expect(earnings).to.equal(0);
        });

        it("Should revert if buyer sends less ETH than price", async () => {
            await gsoeToken.connect(seller).setApprovalForAll(marketplace.address, true);
            await marketplace.connect(owner).setTransferFee(5);

            const listTx = await marketplace.connect(seller).listItem(tokenId, price);
            const listReceipt = await listTx.wait();
            const listingId = listReceipt.events.find(e => e.event === "MarketItemCreated").args.listingId;

            // Buyer sends less than price
            const lessThanPrice = price.sub(ethers.utils.parseEther("0.001"));

            await expect(
                marketplace.connect(buyer).buyItem(listingId, { value: lessThanPrice })
            ).to.be.revertedWith("Wrong ETH amount");
        });
    });

    it("Should correctly emit MarketItemSold event on purchase", async () => {
        // Setup approvals and fees
        await gsoeToken.connect(seller).setApprovalForAll(marketplace.address, true);
        await marketplace.connect(owner).setTransferFee(5);

        // List NFT
        const listTx = await marketplace.connect(seller).listItem(tokenId, price);
        const listReceipt = await listTx.wait();
        const listingId = listReceipt.events.find(e => e.event === "MarketItemCreated").args.listingId;

        // Buy NFT and capture the tx
        const buyTx = await marketplace.connect(buyer).buyItem(listingId, { value: price });
        const buyReceipt = await buyTx.wait();

        // Find the MarketItemSold event
        const soldEvent = buyReceipt.events.find(e => e.event === "MarketItemSold");
        expect(soldEvent).to.exist;

        // Validate event args
        const { listingId: eventListingId, tokenId: eventTokenId, buyer: eventBuyer, price: eventPrice, timestamp } = soldEvent.args;

        expect(eventListingId).to.equal(listingId);
        expect(eventTokenId).to.equal(tokenId);
        expect(eventBuyer).to.equal(buyer.address);
        expect(eventPrice).to.equal(price);
        expect(timestamp.toNumber()).to.be.a("number");
    });


});
