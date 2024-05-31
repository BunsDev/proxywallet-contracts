import { buildModule } from '@nomicfoundation/hardhat-ignition/modules';
import { artifacts } from 'hardhat';
import SmartWalletFactoryV1Module from './SmartWalletFactoryV1';

const NAME = 'NftRent';

const NftRentModule = buildModule(NAME, (m) => {
  const { factory } = m.useModule(SmartWalletFactoryV1Module);

  const nftRent = m.contract(NAME, artifacts.readArtifactSync(NAME), [factory]);

  return { nftRent };
});

export default NftRentModule;
