const config = require('../config');

module.exports = async ({getNamedAccounts, deployments}) => {
    const {deploy, log} = deployments;
    const {deployer} = await getNamedAccounts();
    const RNToken = await deployments.get('RNToken');
    log("Deploying TokenLock....");
    const tokenlock = await deploy('TokenLock', {
      from: deployer,
      args: [
        RNToken.address, 
        Math.floor(new Date(config.UNLOCK_BEGIN).getTime() / 1000),
        Math.floor(new Date(config.UNLOCK_CLIFF).getTime() / 1000),
        Math.floor(new Date(config.UNLOCK_END).getTime() / 1000),
      ],
      log: true,
    });
    log(`07 - Deployed 'TokenLock' at ${tokenlock.address}`);
    return true;
};
module.exports.tags = ['TokenLock'];
module.exports.dependencies = ['RNToken', 'TimeLock'];
module.exports.id = 'TokenLock';