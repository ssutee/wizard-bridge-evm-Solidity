const { deployments, artifacts } = require("hardhat");

module.exports = async (contract) => {
    const { address } = await deployments.get(contract);
    return await artifacts.require(contract).at(address);
};
