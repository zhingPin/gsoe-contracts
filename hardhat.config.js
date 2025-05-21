require("@nomicfoundation/hardhat-toolbox");
// require("@nomicfoundation/hardhat-verify");
// require("dotenv").config();

// const { NEXT_PUBLIC_POLYGON_MUMBAI_RPC, NEXT_PUBLIC_PRIVATE_KEY } = process.env;

/** @type import('hardhat/config').HardhatUserConfig */

module.exports = {
  solidity: "0.8.18",
  // defaultNetwork: "polygon_mumbai",
  networks: {
    hardhat: {},
    
    //   polygon_mumbai: {
    //     url: NEXT_PUBLIC_POLYGON_MUMBAI_RPC,
    // accounts: [`0x${NEXT_PUBLIC_PRIVATE_KEY}`],
    // },
  },
  contractSizer: {
    runOnCompile: true,
  },

  //   // fuji: {
  //   //   url: `Your URL`,
  //   //   accounts: [
  //   //     `0x${"Your Account"}`,
  //   //   ],
  //   // },
  // },
};
