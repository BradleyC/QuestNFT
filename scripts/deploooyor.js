const { ethers } = require("ethers");
const hre = require("hardhat");

async function main() {
  const questDeploy = await hre.ethers.getContractFactory("QuestNFT");
  const questInSitu = await questDeploy.deploy(0,0);
  await questInSitu.deployed();
  console.log("Contract deployed to:", questInSitu.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  })
