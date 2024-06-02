import hre from 'hardhat';

export const deploy = async () => {
  const f = await hre.viem.deployContract('TestERC721', [
    'Test 721',
    'NTT',
    'test-metadata',
  ]);

  console.log(f.address);
};

deploy();
