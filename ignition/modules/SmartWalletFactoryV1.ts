import { buildModule } from '@nomicfoundation/hardhat-ignition/modules';
import { artifacts } from 'hardhat';
import SmartWalletV1Module from './SmartWalletV1';

const NAME = 'SmartWalletFactoryV1';

const SmartWalletFactoryV1Module = buildModule(NAME, (m) => {
  const { impl } = m.useModule(SmartWalletV1Module);
  const factory = m.contract(NAME, artifacts.readArtifactSync(NAME), [impl]);

  return { factory };
});

export default SmartWalletFactoryV1Module;
