import { buildModule } from '@nomicfoundation/hardhat-ignition/modules';
import { artifacts } from 'hardhat';
import { parseEther } from 'viem';

const JAN_1ST_2030 = 1893456000;
const ONE_GWEI = parseEther('0.001');

const NAME = 'Lock';

const LockModule = buildModule(NAME, (m) => {
  const unlockTime = m.getParameter('unlockTime', JAN_1ST_2030);
  const lockedAmount = m.getParameter('lockedAmount', ONE_GWEI);

  const lock = m.contract(
    NAME,
    artifacts.readArtifactSync(NAME),
    [unlockTime],
    {
      value: lockedAmount,
    },
  );

  return { lock };
});

export default LockModule;
