# 🎪 Greatest Show On Earth (GSOE)

A next-generation NFT marketplace empowering artists, performers, and creators with fair revenue-sharing, customizable royalties, and decentralized management — deployable on any **EVM-compatible blockchain**.

---

## 🚀 Features

- 🎭 **Batch Minting** – Mint multiple NFTs in organized batches
- 💸 **Advanced Royalties** – Share royalties with managers, producers, etc.
- 🛒 **List & Sell** – Artists can list, delist, and resell NFTs
- 🧾 **Revenue Splits** – Automated royalty distribution to multiple recipients
- 🔐 **Smart Contract Access Control** – Delegate rights using roles
- ⛓️ **EVM Compatible** – Deploy on Ethereum, Polygon, Arbitrum, Optimism, Base, etc.

---

## 📁 Project Structure

```bash
web3/
├── contracts/
│   └── NFTMarketplace.sol        # Core marketplace logic
│   └── NFTBatchMint.sol         # Batch minting contract (if separate)
│
├── scripts/
│   └── deploy.js                # Deployment script
│
├── test/
│   └── marketplace.test.js      # Contract test cases
│
├── hardhat.config.js            # Hardhat config (uses .env for keys)
├── .env                         # Private key and RPC URLs (excluded via .gitignore)
└── README.md
