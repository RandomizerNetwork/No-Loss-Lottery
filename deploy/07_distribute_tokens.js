const config = require('../config');

const oneToken = ethers.BigNumber.from(10).pow(18);

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

module.exports = async ({getNamedAccounts, deployments}) => {
  const {deployer} = await getNamedAccounts();
  const RandomizerToken = await ethers.getContract('RandomizerToken');
  const RandomizerDailyDraw = await ethers.getContract('RandomizerDailyDraw');
  const RandomizerMetaGamePass = await ethers.getContract('RandomizerMetaGamePass');
  const TimeLock = await ethers.getContract('TimeLock');
  const TokenLock = await ethers.getContract('TokenLock');
  
  // TEAM_TREASURY_GNOSIS_SAFE: "0xe6F7C7caF678A3B7aFb93891907873E88F4FD4AC", // DAILY DRAW TREASURY MULTISG WALLET
  // NLL_TREASURY_GNOSIS_SAFE: "0xe6F7C7caF678A3B7aFb93891907873E88F4FD4AC", // DAILY DRAW TREASURY MULTISG WALLET
  // LOCKED_BURNABLE_TOKENS: "500000000",       // 500M RANDOM (50%) - locked and burned gradually in 10 years
  // LOCKED_DAO_TOKENS: "250000000",            // 250M RANDOM (25%) - locked and released gradually in 5 years
  // TOTAL_DAILY_DRAW_TOKENS: "100000000", // 100M RANDOM (10%) - locked and released gradually in 10 years
  // TOTAL_CONTRIBUTOR_TOKENS: "50000000",      //  50M RANDOM  (5%) - locked and released gradually in 5 years
  // TOTAL_STAKING_TOKENS: "50000000",          //  50M RANDOM  (5%) - locked and released gradually in 10 years
  // TOTAL_YIELD_FARMING_TOKENS: "50000000",    //  50M RANDOM  (5%) - locked and released gradually in 10 years

  if((await TokenLock.lockedAmounts(TimeLock.address)).eq(0)) {
    // Transfer 250M locked RANDOM Tokens to the TokenLock and is fully released in 10 years
    const lockedDAOTokens = oneToken.mul(config.LOCKED_DAO_TOKENS).add();
    await (await RandomizerToken.approve(TokenLock.address, lockedDAOTokens)).wait();
    await (await TokenLock.lock(TimeLock.address, lockedDAOTokens)).wait();

    // [x] 1. MINT RESERVED META GAME PASSES
    await (await RandomizerMetaGamePass.mint(ZERO_ADDRESS, 1)).wait();
    // [x] 2.1 50% to the Treasury which is controlled by the Timelock and approves the Burning of 50% of the RANDOM Tokens by the Daily Draw over a period of 10 years
    await (await RandomizerToken.transfer(config.NLL_TREASURY_GNOSIS_SAFE, oneToken.mul(config.LOCKED_BURNABLE_TOKENS))).wait();
    // [x] 2.2 10% directly to the Daily Draw and is distributed over a period of 10 years
    await (await RandomizerToken.transfer(RandomizerDailyDraw.address, oneToken.mul(config.TOTAL_DAILY_DRAW_TOKENS))).wait();

    // [] 2.3 5% directly to the Staking Contracts and abdicate ownership to the Timelock
    // await (await RandomizerToken.transfer(config.NLL_TREASURY_GNOSIS_SAFE, oneToken.mul(config.TOTAL_DAILY_DRAW_TOKENS))).wait();
    // [] 2.4 5% directly to the Yield Farming Contracts and abdicate ownership to the Timelock
    
    // [x] 2.5 5% to the TokenLock for 5 years for the Core Team
    await (await TokenLock.lock(config.TEAM_TREASURY_GNOSIS_SAFE, oneToken.mul(config.TOTAL_CONTRIBUTOR_TOKENS))).wait();
    // [x] 2.6 25% to the TokenLock for 5 years which is controlled by the Timelock
    await (await TokenLock.lock(TimeLock.address, oneToken.mul(config.LOCKED_DAO_TOKENS))).wait();
        
    // Transfer 2.5B locked RANDOM Tokens to the Daily Draw Gnosis Treasury (half is rewarded and half is burned over a period of 10 years)
    // const totalNLLTokens = oneToken.mul(config.TOTAL_DAILY_DRAW_TOKENS);
    // await (await RandomizerToken.transfer(config.NLL_TREASURY_GNOSIS_SAFE, totalNLLTokens)).wait();

    // // Transfer 1B locked RANDOM DAO tokens to the TokenLock and is fully released in 3 years
    // const totalContributorsTokens = oneToken.mul(config.TOTAL_CONTRIBUTOR_TOKENS);
    // await (await RandomizerToken.transfer(TimeLock.address, totalContributorsTokens)).wait();

    // // Transfer 750M locked RANDOM DAO tokens in the staking contracts
    // const totalStakingTokens = oneToken.mul(config.TOTAL_STAKING_TOKENS);
    // const balanceStaking = await RandomizerToken.balanceOf(deployer);
    // await (await RandomizerToken.transfer(TimeLock.address, balanceStaking.sub(totalStakingTokens))).wait();

    // // Transfer 750M locked RANDOM DAO tokens in the yield farming contracts
    // const totalYieldFarmingTokens = oneToken.mul(config.TOTAL_YIELD_FARMING_TOKENS);
    // const balanceYF = await RandomizerToken.balanceOf(deployer);
    // await (await RandomizerToken.transfer(TimeLock.address, balanceYF.sub(totalYieldFarmingTokens))).wait();

  }

  // Print out balances
  const daoBalance = await RandomizerToken.balanceOf(TimeLock.address);
  console.log(`Token balances:`);
  console.log(`  DAO: ${daoBalance.div(oneToken).toString()}`);
  const contributorBalance = await RandomizerToken.balanceOf(deployer);
  console.log(`  Contributors: ${contributorBalance.div(oneToken).toString()}`);
  const airdropBalance = await RandomizerToken.balanceOf(RandomizerToken.address);
  console.log(`  Airdrop: ${airdropBalance.div(oneToken).toString()}`);
  const tokenlockBalance = await RandomizerToken.balanceOf(TokenLock.address);
  console.log(`  TokenLock: ${tokenlockBalance.div(oneToken).toString()}`);
  const lockedDaoBalance = await TokenLock.lockedAmounts(TimeLock.address);
  console.log(`    DAO: ${lockedDaoBalance.div(oneToken).toString()}`);
  console.log(`    TOTAL: ${lockedDaoBalance.div(oneToken).toString()}`);
  const total = daoBalance.add(contributorBalance).add(airdropBalance).add(tokenlockBalance);
  console.log(`  TOTAL: ${total.div(oneToken).toString()}`);

  return true;
};
module.exports.tags = ['distribute'];
module.exports.dependencies = ['RandomizerToken', "RandomizerMetaGamePass", 'TimeLock', 'TokenLock'];
module.exports.id = 'distribute';