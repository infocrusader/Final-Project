require("@nomiclabs/hardhat-waffle");

const projectID = '3908ce430ae649548caf131252a22d71';
const fs = require('fs');
const keyData = fs.readFileSync('./p-key.txt', {
  encoding:'utf8', flag:'r'
})
// const privateKey = fs.readFileSync(".secret").toString().trim() || "01234567890123456789";
// const infuraId = fs.readFileSync(".infuraid").toString().trim() || "";

module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      chainId: 1337
    },
    
    mumbai: {
      // Infura
      url: `https://polygon-mumbai.infura.io/v3/${projectID}`,
      //url: "https://rpc-mumbai.matic.today",
      accounts: [keyData]
    },
    matic: {
      // Infura
      url: `https://polygon-mainnet.infura.io/v3/${projectID}`,
      //url: "https://rpc-mainnet.maticvigil.com",
      accounts: [keyData]
    }
  },
  solidity: {
    version: "0.8.4",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  }
};