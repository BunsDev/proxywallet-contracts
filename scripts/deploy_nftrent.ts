import hre from 'hardhat';

export const deploy = async () => {
  const f = await hre.viem.deployContract('NftRent', [
    '0x4442c3302524899acf23c971afba39710925df77',
  ]);

  console.log(f.address);
};

deploy();
