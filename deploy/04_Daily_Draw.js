const config = require('../config');

module.exports = async ({getNamedAccounts, deployments}) => {
    const {deploy, log} = deployments;
    const {deployer} = await getNamedAccounts();
    const RandomizerMetaGamePass = await deployments.get('RandomizerMetaGamePass');
    const RandomizerToken = await deployments.get('RandomizerToken');
    const RNDDToken = await deployments.get('RNDDToken');
    log("Deploying RandomizerDailyDraw....");
    const RandomizerDailyDraw = await deploy('RandomizerDailyDraw', {
      from: deployer,
      args: [
        RandomizerToken.address,
        RNDDToken.address,
        RandomizerMetaGamePass.address,
        config.RNDD_TREASURY_GNOSIS_SAFE
      ],
      log: true,
    });
    log(`04 - Deployed 'RandomizerDailyDraw' at ${RandomizerDailyDraw.address}`);
    return true;
};
module.exports.tags = ['RandomizerDailyDraw'];
module.exports.dependencies = ['RandomizerToken', 'RNDDToken', 'RandomizerMetaGamePass'];
module.exports.id = 'RandomizerDailyDraw';