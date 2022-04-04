// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  await hre.run('compile');

  // We get the contract to deploy
  const GoCollectible = await hre.ethers.getContractFactory("GoCollectible");
  const GoFactory = await hre.ethers.getContractFactory("GoFactory");
  const go = await GoCollectible.deploy("0x494449CAE41303b98425F8dDEBF88639759b55c5");

  await go.deployed();

  console.log("GoCollectible deployed to:", go.address);
  console.log("GoCollectible hash:", go.deployTransaction.hash);
  console.log("GoCollectible owner:", go.deployTransaction.from);
  console.log("GoCollectible chainId:", go.deployTransaction.chainId);
  const factory = await GoFactory.deploy("0x494449CAE41303b98425F8dDEBF88639759b55c5");
  await factory.deployed();
  await factory.setNftAddress(go.address);
  console.log("\n");
  console.log("GoFactory deployed to:", factory.address);
  console.log("GoFactory hash:", factory.deployTransaction.hash);
  console.log("GoFactory owner:", factory.deployTransaction.from);
  console.log("GoFactory chainId:", factory.deployTransaction.chainId);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });