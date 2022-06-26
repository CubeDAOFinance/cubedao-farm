// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());


  const CubedaoToken= await ethers.getContractFactory("CubedaoToken");
  const CDAO = await CubedaoToken.deploy();
  await CDAO.deployed();
  console.log("CubedaoToken deployed to:", CDAO.address);

  const Syrup= await ethers.getContractFactory("SyrupBar");
  const syrup= await Syrup.deploy(CDAO.address);
  await syrup.deployed();
  console.log("SyrupBar deployed to:", syrup.address);

  const CDAOPerBlock = "45000000000000000000";
  const startBlock = 436315;
  const devaddr = '0xb05E987a2263B765928F9e67BA5494E727832f11';
  const MasterChef= await ethers.getContractFactory("MasterChef");
  const masterchef= await MasterChef.deploy(CDAO.address,syrup.address,devaddr,CDAOPerBlock,startBlock);
  await masterchef.deployed();
  console.log("MasterChef deployed to:", masterchef.address);


  const SmartChefFactory= await ethers.getContractFactory("SmartChefFactory");
  const smartcheffactory= await SmartChefFactory.deploy();
  await smartcheffactory.deployed();
  console.log("SmartChefFactory deployed to:", smartcheffactory.address);


  const add1 = "0x11B17722F0E877Aa5B4CbEDCC448aD5CC97E8268";
  const mintAmount1 = "20000000000000000000000000";
  const firstMint1= await CDAO.mint(add1,mintAmount1);
  // wait until the transaction is mined
  await firstMint1.wait();
  console.log("Mint:",await CDAO.balanceOf(add1));

  const add2 = "0xfdE3ee0f427AD75A5a057F26Ab87E051BE44F6Ef";
  const mintAmount2 = "2000000000000000000000000";
  const firstMint2= await CDAO.mint(add2,mintAmount2);
  // wait until the transaction is mined
  await firstMint2.wait();
  console.log("Mint:",await CDAO.balanceOf(add2));

  const add3 = "0x3B024d206358aA2c6794219Eed418f5f903F567C";
  const mintAmount3 = "3000000000000000000000000";
  const firstMint3= await CDAO.mint(add3,mintAmount3);
  // wait until the transaction is mined
  await firstMint3.wait();
  console.log("Mint:",await CDAO.balanceOf(add3));

  const add4 = "0xCaaD0A0840ed34D138d9961b3903185064F13BbE";
  const mintAmount4 = "25000000000000000000000000";
  const firstMint4= await CDAO.mint(add4,mintAmount4);
  // wait until the transaction is mined
  await firstMint4.wait();
  console.log("Mint:",await CDAO.balanceOf(add4));


  const setCdaoOwner = await CDAO.transferOwnership(masterchef.address);
  // wait until the transaction is mined
  await setCdaoOwner.wait();
  console.log("set Cdao owner:",await CDAO.owner());

  const setSyrupBarOwner = await syrup.transferOwnership(masterchef.address);
  // wait until the transaction is mined
  await setSyrupBarOwner.wait();
  console.log("set SyrupBar owner:",await syrup.owner());

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
