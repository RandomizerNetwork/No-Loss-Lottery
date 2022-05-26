const hre = require("hardhat");

async function main() {
  const block = await hre.ethers.provider.getBlock("latest");
  const openingTime = Math.floor(block.timestamp) + 1 // now + 1 hour = 3600
  
  // We deploy the RANDOM Governance Token
  const RandomizerToken = await hre.ethers.getContractFactory("RandomizerToken");
  const rn = await RandomizerToken.deploy(openingTime);
  await rn.deployed();
  console.log("RandomizerToken deployed to:", rn.address);

  // We deploy the NLL Utility Token
  const NLLToken = await hre.ethers.getContractFactory("NLLToken");
  const nll = await NLLToken.deploy(openingTime);
  await nll.deployed();
  console.log("NLLToken deployed to:", nll.address);

  // We deploy Meta Game Passes
  const RandomizerMetaGamePass = await hre.ethers.getContractFactory("RandomizerMetaGamePass");
  const gamepass = await RandomizerMetaGamePass.deploy(openingTime);
  await gamepass.deployed();
  console.log("RandomizerMetaGamePass deployed to:", gamepass.address);

  // We deploy the Governor Contract
  // We deploy the Timelock Contract
  // We deploy the Token Version of the Daily Draw
  // We deploy the NFTs Version of the Daily Draw
}

// This pattern enables async/await everywhere and properly handles errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});