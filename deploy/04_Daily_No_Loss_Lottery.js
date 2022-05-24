const config = require('../config');

module.exports = async ({getNamedAccounts, deployments}) => {
    const {deploy, log} = deployments;
    const {deployer} = await getNamedAccounts();
    const RandomizerMetaGamePass = await deployments.get('RandomizerMetaGamePass');
    const RandomizerToken = await deployments.get('RandomizerToken');
    const NLLToken = await deployments.get('NLLToken');
    log("Deploying RandomizerDailyNoLossLottery....");
    const RandomizerDailyNoLossLottery = await deploy('RandomizerDailyNoLossLottery', {
      from: deployer,
      args: [
        RandomizerToken.address,
        NLLToken.address,
        RandomizerMetaGamePass.address,
        config.NLL_TREASURY_GNOSIS_SAFE
      ],
      log: true,
    });
    log(`04 - Deployed 'RandomizerDailyNoLossLottery' at ${RandomizerDailyNoLossLottery.address}`);
    return true;
};
module.exports.tags = ['RandomizerDailyNoLossLottery'];
module.exports.dependencies = ['RandomizerToken', 'NLLToken', 'RandomizerMetaGamePass'];
module.exports.id = 'RandomizerDailyNoLossLottery';