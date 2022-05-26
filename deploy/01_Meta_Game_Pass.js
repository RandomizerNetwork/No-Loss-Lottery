const config = require('../config');

module.exports = async ({getNamedAccounts, deployments}) => {
    const {deploy, log} = deployments;
    const {deployer} = await getNamedAccounts();
    log("Deploying RandomizerMetaGamePass....");
    const RandomizerMetaGamePass = await deploy('RandomizerMetaGamePass', {
      from: deployer,
      args: [
        "Randomizer Meta Pass",           // Token Name
        "RMP",                            // Token Symbol
        "1",                              // Timestamp starts now
        config.NLL_TREASURY_GNOSIS_SAFE,  // Gnosis Safe that holds in circulation 50% of Tokens which is burned daily over a period of 10 years
        "500",                            // Opensea Royalties Basepoints
        "500"                             // Max Batch Minting used only for pre-reserved Meta Passes
      ],
      log: true,
    });
    log(`01 - Deployed 'RandomizerMetaGamePass' at ${RandomizerMetaGamePass.address}`);
    return true;
};
module.exports.tags = ['RandomizerMetaGamePass'];
module.exports.id = 'RandomizerMetaGamePass';