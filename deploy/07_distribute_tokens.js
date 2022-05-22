const config = require('../config');

const oneToken = ethers.BigNumber.from(10).pow(18);

module.exports = async ({getNamedAccounts, deployments}) => {
  const {deployer} = await getNamedAccounts();
  const RNToken = await ethers.getContract('RNToken');
  const TimeLock = await ethers.getContract('TimeLock');
  const TokenLock = await ethers.getContract('TokenLock');

  // [x] 1. send 2.5B to NLL Treasury
  // [x] 2. lock 5B DAO Tokens in TokenLock and release to Timelock
  // [x] 3. lock 1B DAO Tokens in TokenLock and release to Contributors
  // [] 4. send 750M DAO Tokens to Staking Contracts
  // [] 4. send 750M DAO Tokens to Yield Farming Contracts

  // NLL_TREASURY_GNOSIS_SAFE: "0xe6F7C7caF678A3B7aFb93891907873E88F4FD4AC", // NO LOSS LOTTERY TREASURY MULTISG WALLET
  // LOCKED_DAO_TOKENS: "5000000000",            // 5 Billion RN (50%)    - locked and released gradually in 5 years
  // TOTAL_NO_LOSS_LOTTERY_TOKENS: "2500000000", // 2.5 Billion RN (25%)  - locked and released gradually in 10 years
  // TOTAL_CONTRIBUTOR_TOKENS: "1000000000",     // 1 Billion RN (10%)    - locked and released gradually in 5 years
  // TOTAL_STAKING_TOKENS: "750000000",          // 750 Million RN (7.5%) - locked and released gradually in 10 years
  // TOTAL_YIELD_FARMING_TOKENS: "750000000",    // 750 Million RN (7.5%) - locked and released gradually in 10 years    

  if((await TokenLock.lockedAmounts(TimeLock.address)).eq(0)) {

    // Transfer 5B locked RN Tokens to the TokenLock and is fully released in 3 years
    const lockedDAOTokens = oneToken.mul(config.LOCKED_DAO_TOKENS);
    await (await RNToken.approve(TokenLock.address, lockedDAOTokens)).wait();
    await (await RNToken.approve(TokenLock.address, lockedDAOTokens)).wait();
    await (await TokenLock.lock(TimeLock.address, lockedDAOTokens)).wait();

    // Transfer 2.5B locked RN Tokens to the No Loss Lottery Gnosis Treasury (half is rewarded and half is burned over a period of 10 years)
    const totalNLLTokens = oneToken.mul(config.TOTAL_NO_LOSS_LOTTERY_TOKENS);
    await (await RNToken.transfer(config.NLL_TREASURY_GNOSIS_SAFE, totalNLLTokens)).wait();

    // Transfer 1B locked RN DAO tokens to the TokenLock and is fully released in 3 years
    const totalContributorsTokens = oneToken.mul(config.TOTAL_CONTRIBUTOR_TOKENS);
    await (await RNToken.transfer(TimeLock.address, totalContributorsTokens)).wait();

    // Transfer 750M locked RN DAO tokens in the staking contracts
    const totalStakingTokens = oneToken.mul(config.TOTAL_STAKING_TOKENS);
    const balanceStaking = await RNToken.balanceOf(deployer);
    await (await RNToken.transfer(TimeLock.address, balanceStaking.sub(totalStakingTokens))).wait();

    // Transfer 750M locked RN DAO tokens in the yield farming contracts
    const totalYieldFarmingTokens = oneToken.mul(config.TOTAL_YIELD_FARMING_TOKENS);
    const balanceYF = await RNToken.balanceOf(deployer);
    await (await RNToken.transfer(TimeLock.address, balanceYF.sub(totalYieldFarmingTokens))).wait();

  }

  // Print out balances
  const daoBalance = await RNToken.balanceOf(TimeLock.address);
  console.log(`Token balances:`);
  console.log(`  DAO: ${daoBalance.div(oneToken).toString()}`);
  const contributorBalance = await RNToken.balanceOf(deployer);
  console.log(`  Contributors: ${contributorBalance.div(oneToken).toString()}`);
  const airdropBalance = await RNToken.balanceOf(RNToken.address);
  console.log(`  Airdrop: ${airdropBalance.div(oneToken).toString()}`);
  const tokenlockBalance = await RNToken.balanceOf(TokenLock.address);
  console.log(`  TokenLock: ${tokenlockBalance.div(oneToken).toString()}`);
  const lockedDaoBalance = await TokenLock.lockedAmounts(TimeLock.address);
  console.log(`    DAO: ${lockedDaoBalance.div(oneToken).toString()}`);
  console.log(`    TOTAL: ${lockedDaoBalance.div(oneToken).toString()}`);
  const total = daoBalance.add(contributorBalance).add(airdropBalance).add(tokenlockBalance);
  console.log(`  TOTAL: ${total.div(oneToken).toString()}`);

  return true;
};
module.exports.tags = ['distribute'];
module.exports.dependencies = ['RNToken', 'TimeLock', 'TokenLock'];
module.exports.id = 'distribute';