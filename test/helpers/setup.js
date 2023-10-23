const { web3 } = require("hardhat");
const { toWei } = require("web3-utils");
const getContract = require("./getContract");

module.exports = async () => {
  const accounts = await web3.eth.getAccounts();
  const currentBlock = await web3.eth.getBlock("latest");
  const deployer = accounts[0];
  const signer = accounts[1];
  const bob = accounts[2];
  const marry = accounts[3];
  const john = accounts[4];

  const bridge = await getContract("WizardBridgeEVM");
  const jfin = await getContract("JFINToken");

  return {
    accounts,
    currentBlock,
    deployer,
    signer,
    bob,
    marry,
    john,
    bridge,
    jfin,
  };
};
