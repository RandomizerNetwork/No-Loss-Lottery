module.exports = async ({getNamedAccounts, deployments}) => {
  const {log} = deployments;
  const RNMetaGamePass = await ethers.getContract('RNMetaGamePass');
  const RNToken = await ethers.getContract('RNToken');
  const NLLToken = await ethers.getContract('NLLToken');
  const TimeLock = await ethers.getContract('TimeLock');
  const RNDailyNoLossLottery = await ethers.getContract('RNDailyNoLossLottery');

  await (await NLLToken.setNoLossLotteries(RNDailyNoLossLottery.address, true)).wait(1); // whitelist the No Loss Lottery to mint daily rewards
  await (await RNMetaGamePass.transferOwnership(TimeLock.address)).wait(1);
  await (await RNToken.transferOwnership(TimeLock.address)).wait(1); // whitelist the No Loss Lottery to mint daily rewards
  await (await NLLToken.transferOwnership(TimeLock.address)).wait(1); // whitelist the No Loss Lottery to mint daily rewards
  await (await RNDailyNoLossLottery.transferOwnership(TimeLock.address)).wait(1);

  log(`08 - Transfer Ownerships to Timelock`);
  return true;
};
module.exports.tags = ['ownership'];
module.exports.dependencies = ['RNMetaGamePass', 'RNToken', 'NLLToken', 'TimeLock', 'RNDailyNoLossLottery'];
module.exports.id = 'ownership';