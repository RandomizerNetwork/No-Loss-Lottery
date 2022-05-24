module.exports = async ({getNamedAccounts, deployments}) => {
    const {deploy, log} = deployments;
    const {deployer} = await getNamedAccounts();
    log("Deploying RandomizerToken....");
    const RandomizerToken = await deploy('RandomizerToken', {
      from: deployer,
      args: [],
      log: true,
    });
    log(`02 - Deployed 'RandomizerToken' at ${RandomizerToken.address}`);
    await delegate(RandomizerToken.address, deployer); // delegate to self
    log(`02 - Delegated`);
    return true;
};
module.exports.tags = ['RandomizerToken'];
module.exports.id = 'RandomizerToken';

const delegate = async (governanceTokenAddress, delegatedAccount) => {
  const governanceToken = await ethers.getContractAt("RandomizerToken", governanceTokenAddress)
  const txResponse = await governanceToken.delegate(delegatedAccount);
  await txResponse.wait(1);
  console.log(`Checkpoints: ${await governanceToken.numCheckpoints(delegatedAccount)}`);
}