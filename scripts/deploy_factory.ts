import hre from 'hardhat';

export const deploy = async () => {
  const f = await hre.viem.deployContract('SmartWalletFactoryV1', [
    {
      clRegistrar: '0x0Bc5EDC7219D272d9dEDd919CE2b4726129AC02B',
      clRegistry: '0x08a8eea76D2395807Ce7D1FC942382515469cCA1',
      uniswapV3Router: '0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45',
      wethToken: '0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270',
      linkToken: '0x53E0bca35eC356BD5ddDFebbD1Fc0fD03FaBad39',
      linkTokenNative: '0xb0897686c545045afc77cf20ec7a532e3120e0f1',
      linkTokenPegSwap: '0xAA1DC356dc4B18f30C347798FD5379F3D77ABC5b',
      linkFeePerExecution: '1500000000000000000',
      wethToLinkSwapPath:
        '0x53e0bca35ec356bd5dddfebbd1fc0fd03fabad39000bb80d500b1d8e8ef31e21c99d1db9a6444d3adf1270',
    },
    '0x360c179c809122dddfa0fb584b5433f0dbddb4cd',
  ]);

  console.log(f.address);
};

deploy();
