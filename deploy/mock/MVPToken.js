module.exports = async ({ getNamedAccounts, deployments, network }) => {
  if (!network.tags.production) {
    const { deployer } = await getNamedAccounts();
    const { deploy } = deployments;
    await deploy("MVPToken", {
      from: deployer,
      log: true,
    });
  }
};
module.exports.tags = ["MVPToken", "MockTokens"];
