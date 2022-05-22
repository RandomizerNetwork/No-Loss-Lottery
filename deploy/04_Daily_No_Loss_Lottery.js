const config = require('../config');

module.exports = async ({getNamedAccounts, deployments}) => {
    const {deploy, log} = deployments;
    const {deployer} = await getNamedAccounts();
    const RNMetaGamePass = await deployments.get('RNMetaGamePass');
    const RNToken = await deployments.get('RNToken');
    const NLLToken = await deployments.get('NLLToken');
    log("Deploying RNDailyNoLossLottery....");
    const RNDailyNoLossLottery = await deploy('RNDailyNoLossLottery', {
      from: deployer,
      args: [
        RNToken.address,
        NLLToken.address,
        RNMetaGamePass.address,
        config.NLL_TREASURY_GNOSIS_SAFE
      ],
      log: true,
    });
    log(`04 - Deployed 'RNDailyNoLossLottery' at ${RNDailyNoLossLottery.address}`);
    return true;
};
module.exports.tags = ['RNDailyNoLossLottery'];
module.exports.dependencies = ['RNToken', 'NLLToken', 'RNMetaGamePass'];
module.exports.id = 'RNDailyNoLossLottery';