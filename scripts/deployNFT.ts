
import { ethers } from "hardhat";
import { string } from "hardhat/internal/core/params/argumentTypes";


async function main() {

    const WhaleNFT = await ethers.getContractFactory('SporkWhaleNFT');
    const whaleNFT = await WhaleNFT.connect((await ethers.getSigners())[2]).deploy(String(process.env.OPERATOR), String(process.env.NFT_BASE_URI));
    await whaleNFT.waitForDeployment();
    console.log('WhaleNFT deployed to:', await whaleNFT.getAddress());

}


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
  