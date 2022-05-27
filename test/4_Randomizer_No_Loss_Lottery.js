const chai = require("chai");
const { network, ethers } = require("hardhat");
const { BN, constants, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
const { solidity } = require("ethereum-waffle");
chai.use(solidity);
const { expect } = require("chai");
const toWei = (amount) => ethers.utils.parseEther(amount)
const fromWei = (amount) => ethers.utils.formatEther(amount)

const minter = ethers.utils.getAddress("0xd1E006022f11a1878b391b92A69Df1F0741F6a92");
const wallet = ethers.utils.getAddress("0x63625Cfd44F4a29013D30F1ba02Ca69c1976b7da");

describe("RANDOM_RNDDV2", function () {
  beforeEach(async () => {
    const [deployer, player] = await ethers.getSigners();    
    const RANDOMToken = await ethers.getContractAt("RANDOMToken", "0x551b7377F547765502c323b50442e0A8581Db643");
    const RNDDToken = await ethers.getContractAt("RNDDToken", "0x6b70e4966e66AAafA9956Ed19B38A6c5dae4FC56");
    const RandomizerDailyDraw = await ethers.getContractAt("RandomizerDailyDraw", "0x0161C8890eC9E71D9E9a303a3C6b726e5ca815ee");
    console.log('deployer', deployer.address);
    console.log('player', player.address);
    console.log('RANDOMToken', RANDOMToken.address);
    console.log('RNDDToken', RNDDToken.address);
    console.log('RandomizerDailyDraw', RandomizerDailyDraw.address);
    console.log('subscriptionId', await RandomizerDailyDraw.subscriptionId());
  });
  
  it("should check if token has correct values", async () => {
    console.log('wtf merge ?')
    expect(await RANDOMToken.name()).to.equal('Randomizer Network', "Token name is not correct")
    expect(await RANDOMToken.symbol()).to.equal('RANDOM', "Token symbol is not correct")
    expect(await RANDOMToken.decimals()).to.equal(18, "Token decimals is not correct")
    expect(await RANDOMToken.balanceOf(minter)).to.equal(await RANDOMToken.totalSupply(), "Owner should own all 1B RANDOM Tokens")
  })

});