module.exports = async ({ getNamedAccounts, deployments, network }) => {
  const { deployer, signer } = await getNamedAccounts();
  const { deploy } = deployments;
  
  await deploy("WizardBridgeEVM", {
    contract: "WizardBridgeEVM",    
    args: [signer, 0],
    from: deployer,
    log: true,
  });    
  
};
module.exports.tags = ["WizardBridgeEVM"];

  