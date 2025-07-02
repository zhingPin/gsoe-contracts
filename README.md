# 🎪 Greatest Show On Earth (GSOE)
A next-generation NFT marketplace empowering artists, performers, and creators with fair revenue-sharing, multi-recipient royalties, and decentralized management — deployable on any EVM-compatible blockchain.

🚀 Features
🎭 Batch Minting – Mint multiple NFTs in organized batches

💸 Advanced Royalties – Multi-recipient royalty distribution (e.g., artist, producer, manager)

🛒 List, Delist, and Sell NFTs – Manage listings via a decentralized marketplace

🧾 Revenue Splits – Automated on-chain royalty distribution

🧑‍🤝‍🧑 Delegated Roles – Smart contract roles for minting, listing, and managing items

⛓️ EVM Compatible – Deployable to Ethereum, Polygon, Arbitrum, Optimism, Base, and more

# 🏗️ Smart Contract Architecture

🔹 GSOEToken.sol
> ERC721-compliant NFT contract with AccessControl. Grants MINTER_ROLE to the marketplace for trusted minting.

🔹 MarketplaceCore.sol
> Handles core marketplace logic: listing, delisting, purchasing, royalty calculations, and revenue tracking.

🔹 NFTMarketMinter.sol
> User-facing contract that handles NFT minting and listing in a single transaction.

🔹 MarketplaceView.sol
> Read-only contract that efficiently aggregates marketplace state, listings, and earnings for frontend use.

# 📁 Project Structure
`
web3/
├── contracts/
│   ├── GSOEToken.sol              # ERC721 token with roles
│   ├── MarketplaceCore.sol        # Core marketplace logic
│   ├── NFTMarketMinter.sol        # Mint & list logic for user interaction
│   └── MarketplaceView.sol        # View-only queries for frontend
│
├── interfaces/
│   ├── INFT.sol                   # GSOEToken interface
│   ├── IMarketplaceCore.sol       # Marketplace interface for View & Minter
│
├── lib/
│   └── MarketplaceLib.sol         # Shared struct (MarketItem) + helper functions
│
├── scripts/
│   └── deploy.js                  # Deploys all contracts + assigns roles
│
├── test/
│   └── marketplace.test.js        # Smart contract unit tests
│
├── hardhat.config.js              # Hardhat configuration
├── .env                           # Environment variables (excluded via .gitignore)
└── README.md                      # This file
`

## 🌐 Environment Setup

Create a `.env` file in the project root with the following:

```env
TEST_PRIVATE_KEY=your_testnet_private_key_without_0x
LIVE_PRIVATE_KEY=your_mainnet_private_key_without_0x
POLYGON_AMOY_RPC=https://rpc-amoy.polygon.technology
POLYGONSCAN_API_KEY=your_polygonscan_api_key (optional)
```
🔐 Security Note: Never commit .env to version control.

## ⚙️ Hardhat Configuration

Supports the following networks:

- `hardhat` – Local development chain
- `polygon_amoy` – Polygon Amoy testnet (RPC defined in `.env`)


## 🧪 Development & Deployment
> Compile, Test & Analyze
- `npx hardhat compile`          # Compile contracts
- `npx hardhat test`              # Run contract unit tests
- `npx hardhat coverage`         # Generate coverage report
- `npx hardhat size-contracts`    # Show contract size summary


> Deploy to Polygon Amoy
- `npx hardhat run scripts/deploy.js --network polygon_amoy`

