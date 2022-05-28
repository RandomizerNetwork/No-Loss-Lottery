module.exports = async ({getNamedAccounts, deployments}) => {
    const {deploy, log} = deployments;
    const {deployer} = await getNamedAccounts();
    log("Deploying RNDDToken....");
    const token = await deploy('RNDDToken', {
      from: deployer,
      args: [],
      log: true,
    });
    log(`03 - Deployed 'RNDDToken' at ${token.address}`);
    return true;
};
module.exports.tags = ['RNDDToken'];
module.exports.id = 'RNDDToken';