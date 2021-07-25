const hre = require('hardhat')

module.exports = async function() {
    const accounts = await hre.web3.eth.getAccounts();
    // deploy SignToken
    const SignToken = await hre.artifacts.require("SignToken");
    const signToken = await SignToken.new();
    return {signToken}
}