module.exports = async ({getNamedAccounts, deployments}) => {
  const {log} = deployments;
  const RandomizerMetaGamePass = await ethers.getContract('RandomizerMetaGamePass');
  const RandomizerToken = await ethers.getContract('RandomizerToken');
  const RNDDToken = await ethers.getContract('RNDDToken');
  const TimeLock = await ethers.getContract('TimeLock');
  const RandomizerDailyDraw = await ethers.getContract('RandomizerDailyDraw');

  await (await RNDDToken.setDailyDrawGame(RandomizerDailyDraw.address, true)).wait(1); // whitelist the Daily Draw to mint daily rewards
  await (await RandomizerMetaGamePass.transferOwnership(TimeLock.address)).wait(1);
  await (await RandomizerToken.transferOwnership(TimeLock.address)).wait(1); // whitelist the Daily Draw to mint daily rewards
  await (await RNDDToken.transferOwnership(TimeLock.address)).wait(1); // whitelist the Daily Draw to mint daily rewards
  await (await RandomizerDailyDraw.transferOwnership(TimeLock.address)).wait(1);

  log(`08 - Transfer Ownerships to Timelock`);
  return true;
};

module.exports.tags = ['ownership'];
module.exports.dependencies = ['RandomizerMetaGamePass', 'RandomizerToken', 'RNDDToken', 'TimeLock', 'RandomizerDailyDraw'];
module.exports.id = 'ownership';