import { buildModule } from '@nomicfoundation/hardhat-ignition/modules';
import { artifacts } from 'hardhat';

const NAME = 'SmartWalletV1';

const SmartWalletV1Module = buildModule(NAME, (m) => {
  const impl = m.contract(NAME, artifacts.readArtifactSync(NAME), []);

  return { impl };
});

export default SmartWalletV1Module;
