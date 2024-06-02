import hre from 'hardhat';

export const deploy = async () => {
  const f = await hre.viem.deployContract('SmartWalletV1', []);

  console.log(f.address);
};

deploy();
