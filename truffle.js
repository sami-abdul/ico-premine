//var HDWalletProvider = require("truffle-hdwallet-provider");
//
//var infura_apikey = "Q4OvfConFr7wxPZkT6Lu ";
//var mnemonic = "drill coconut depth economy true toddler luggage kind quick vote valid lemon";

module.exports = {
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      network_id: '*' // Match any network id
    }
//    ropsten: {
//      provider: new HDWalletProvider(mnemonic, "https://ropsten.infura.io/" + infura_apikey),
//      network_id: 3
//    }
  }
};