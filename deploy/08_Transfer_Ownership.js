module.exports = async ({getNamedAccounts, deployments}) => {
  const {log} = deployments;
  const RandomizerMetaGamePass = await ethers.getContract('RandomizerMetaGamePass');
  const RandomizerToken = await ethers.getContract('RandomizerToken');
  const NLLToken = await ethers.getContract('NLLToken');
  const TimeLock = await ethers.getContract('TimeLock');
  const RandomizerDailyNoLossLottery = await ethers.getContract('RandomizerDailyNoLossLottery');

  await (await NLLToken.setNoLossLotteries(RandomizerDailyNoLossLottery.address, true)).wait(1); // whitelist the No Loss Lottery to mint daily rewards
  await (await RandomizerMetaGamePass.transferOwnership(TimeLock.address)).wait(1);
  await (await RandomizerToken.transferOwnership(TimeLock.address)).wait(1); // whitelist the No Loss Lottery to mint daily rewards
  await (await NLLToken.transferOwnership(TimeLock.address)).wait(1); // whitelist the No Loss Lottery to mint daily rewards
  await (await RandomizerDailyNoLossLottery.transferOwnership(TimeLock.address)).wait(1);

  log(`08 - Transfer Ownerships to Timelock`);
  return true;
};
module.exports.tags = ['ownership'];
module.exports.dependencies = ['RandomizerMetaGamePass', 'RandomizerToken', 'NLLToken', 'TimeLock', 'RandomizerDailyNoLossLottery'];
module.exports.id = 'ownership';