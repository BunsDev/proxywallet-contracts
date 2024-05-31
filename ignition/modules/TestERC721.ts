import { buildModule } from '@nomicfoundation/hardhat-ignition/modules';
import { artifacts } from 'hardhat';
import SmartWalletFactoryV1Module from './SmartWalletFactoryV1';

const NAME = 'TestERC721';

const TestERC721Module = buildModule(NAME, (m) => {
  const name = m.getParameter('testERC721Name');
  const symbol = m.getParameter('testERC721Symbol');
  const baseUri = m.getParameter('testERC721BaseUri');

  const token = m.contract(NAME, artifacts.readArtifactSync(NAME), [
    name,
    symbol,
    baseUri,
  ]);

  return { token };
});

export default TestERC721Module;
