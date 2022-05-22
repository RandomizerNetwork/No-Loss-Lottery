module.exports = async ({getNamedAccounts, deployments}) => {
    const {deploy, log} = deployments;
    const {deployer} = await getNamedAccounts();
    log("Deploying RNToken....");
    const RNToken = await deploy('RNToken', {
      from: deployer,
      args: [],
      log: true,
    });
    log(`02 - Deployed 'RNToken' at ${RNToken.address}`);
    await delegate(RNToken.address, deployer); // delegate to self
    log(`02 - Delegated`);
    return true;
};
module.exports.tags = ['RNToken'];
module.exports.id = 'RNToken';

const delegate = async (governanceTokenAddress, delegatedAccount) => {
  const governanceToken = await ethers.getContractAt("RNToken", governanceTokenAddress)
  const txResponse = await governanceToken.delegate(delegatedAccount);
  await txResponse.wait(1);
  console.log(`Checkpoints: ${await governanceToken.numCheckpoints(delegatedAccount)}`);
}