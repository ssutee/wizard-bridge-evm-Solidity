module.exports = async ({ getNamedAccounts, deployments, network }) => {
  if (!network.tags.production) {
    const { deployer } = await getNamedAccounts();
    const { deploy } = deployments;
    await deploy("JFINToken", {
      from: deployer,
      log: true,
    });
  }
};
module.exports.tags = ["JFINToken", "MockTokens"];
