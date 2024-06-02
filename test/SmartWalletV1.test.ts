import {
  time,
  loadFixture,
  setBalance,
} from '@nomicfoundation/hardhat-toolbox-viem/network-helpers';
import { expect } from 'chai';
import { viem, ignition } from 'hardhat';
import {
  Address,
  getAddress,
  keccak256,
  parseGwei,
  encodePacked,
  encodeAbiParameters,
  Hex,
  parseUnits,
  zeroAddress,
} from 'viem';

import FactoryModule from '@/ignition/modules/SmartWalletFactoryV1';
import WalletModule from '@/ignition/modules/SmartWalletV1';

const linkTokenAddress = getAddress(
  '0x514910771AF9Ca656af840dff83E8264EcF986CA',
);
const clRegistrarAddress = getAddress(
  '0x6B0B234fB2f380309D47A7E9391E29E9a179395a',
);
const clRegistryAddress = getAddress(
  '0x6593c7De001fC8542bB1703532EE1E5aA0D458fD',
);
const uniswapV3RouterAddress = getAddress(
  '0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45',
);
const wethTokenAddress = getAddress(
  '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2',
);

// const linkTokenAddress = getAddress(
//   '0x779877A7B0D9E8603169DdbD7836e478b4624789',
// );
// const clRegistrarAddress = getAddress(
//   '0xb0E49c5D0d05cbc241d68c05BC5BA1d1B7B72976',
// );
// const clRegistryAddress = getAddress(
//   '0x86EFBD0b6736Bed994962f9797049422A3A8E8Ad',
// );
// const uniswapV3RouterAddress = getAddress(
//   '0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E',
// );
// const wethTokenAddress = getAddress(
//   '0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14',
// );

const wethToLinkSwapPath = encodePacked(
  ['address', 'uint24', 'address'],
  [linkTokenAddress, 3000, wethTokenAddress],
);

console.log({ wethToLinkSwapPath });

type DefaultFixtureReturn = Awaited<ReturnType<typeof deployFixture>>;

const createWalletTest = async (
  { salt = 'default' }: { salt?: string },
  fixture: DefaultFixtureReturn,
) => {
  const realSalt = keccak256(encodePacked(['string'], [salt]));
  const walletAddress = await fixture.factory.read.predictCreate2Wallet([
    fixture.owner.account.address,
    realSalt,
  ]);

  await fixture.factory.write.create2Wallet([
    fixture.owner.account.address,
    fixture.owner.account.address,
    realSalt,
  ]);

  return await viem.getContractAt('SmartWalletV1', walletAddress, {
    client: { wallet: fixture.owner },
  });
};

type Wallet = Awaited<ReturnType<typeof createWalletTest>>;
type CommonParams = {
  revertedWith?: string;
};

const addToAllowListTest = async (
  { wallet, addAddress }: { addAddress?: Address; wallet: Wallet },
  fixture: DefaultFixtureReturn,
  common?: CommonParams,
) => {
  addAddress = fixture.owner.account.address;

  if (common?.revertedWith !== undefined) {
    await expect(wallet.write.addToAllowlist([addAddress])).to.be.rejectedWith(
      common.revertedWith,
    );
    return;
  }

  await wallet.write.addToAllowlist([addAddress]);

  expect(await wallet.read.allowlist([addAddress])).eq(true);
};

const removeFromAllowListTest = async (
  { wallet, addAddress }: { addAddress?: Address; wallet: Wallet },
  fixture: DefaultFixtureReturn,
  common?: CommonParams,
) => {
  addAddress = fixture.otherAccounts[0].account.address;

  if (common?.revertedWith !== undefined) {
    await expect(wallet.write.removeFromAllowlist([addAddress])).rejectedWith(
      common.revertedWith,
    );
    return;
  }

  await wallet.write.removeFromAllowlist([addAddress]);

  expect(await wallet.read.allowlist([addAddress])).eq(false);
};

const executeTest = async (
  {
    to,
    calldata = '0x',
    value = 0n,
    wallet,
  }: { to: Address; calldata?: Hex; value?: bigint; wallet: Wallet },
  fixture: DefaultFixtureReturn,
  common?: CommonParams,
) => {
  if (common?.revertedWith !== undefined) {
    await expect(wallet.write.execute([to, value, calldata])).rejectedWith(
      common.revertedWith,
    );
    return;
  }

  await wallet.write.execute([to, value, calldata]);
};

const addToAutoExecuteTest = async (
  {
    id = keccak256(encodePacked(['uint256'], [1n])),
    to,
    callback = zeroAddress,
    calldata = '0x',
    value = 0n,
    after,
    wallet,
  }: {
    id?: Hex;
    to: Address;
    callback?: Address;
    calldata?: Hex;
    value?: bigint;
    after?: number | bigint;
    wallet: Wallet;
  },
  fixture: DefaultFixtureReturn,
  common?: CommonParams,
) => {
  after ??=
    (await fixture.publicClient.getBlock({ blockTag: 'latest' })).timestamp +
    3600n;

  if (common?.revertedWith !== undefined) {
    await expect(
      wallet.write.addToAutoExecute([
        id,
        callback,
        calldata,
        to,
        value,
        BigInt(after!),
      ]),
    ).rejectedWith(common.revertedWith);
    return;
  }

  const uniqueId = await wallet.simulate.addToAutoExecute([
    id,
    callback,
    calldata,
    to,
    value,
    BigInt(after!),
  ]);

  await wallet.write.addToAutoExecute([
    id,
    callback,
    calldata,
    to,
    value,
    BigInt(after!),
  ]);
};

const blacklistTest = async (
  {
    to,
    selector = '0x',
    wallet,
  }: { to: Address; selector?: Hex; wallet: Wallet },
  fixture: DefaultFixtureReturn,
  common?: CommonParams,
) => {
  if (common?.revertedWith !== undefined) {
    await expect(wallet.write.blacklist([to, selector])).rejectedWith(
      common.revertedWith,
    );
    return;
  }

  await wallet.write.blacklist([to, selector]);

  expect(await wallet.read.blacklistedFunctions([to, selector])).eq(true);
};
const performUpkeep = async (
  { data = '0x', wallet }: { data?: Hex; wallet: Wallet },
  fixture: DefaultFixtureReturn,
  common?: CommonParams,
) => {
  if (common?.revertedWith !== undefined) {
    await expect(wallet.write.performUpkeep([data])).rejectedWith(
      common.revertedWith,
    );
    return;
  }

  await wallet.write.performUpkeep([data]);
};

async function deployFixture() {
  const [owner, ...otherAccounts] = await viem.getWalletClients();

  const { impl: walletImplementation } = await ignition.deploy(
    WalletModule,
    {},
  );
  const { factory } = await ignition.deploy(FactoryModule, {
    parameters: {
      SmartWalletFactoryV1: {
        commonDeployParams: {
          linkToken: linkTokenAddress,
          linkTokenNative: linkTokenAddress,
          linkTokenPegSwap: zeroAddress,
          clRegistrar: clRegistrarAddress,
          clRegistry: clRegistryAddress,
          linkFeePerExecution: '100000000000000000',
          uniswapV3Router: uniswapV3RouterAddress,
          wethToken: wethTokenAddress,
          wethToLinkSwapPath,
        },
      },
    },
  });

  const publicClient = await viem.getPublicClient();

  return {
    publicClient,
    otherAccounts,
    owner,
    factory,
    walletImplementation,
  };
}
describe('SmartWalletV1', function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.

  describe('Create wallet', function () {
    it('Should deploy a wallet', async function () {
      const fixture = await loadFixture(deployFixture);

      await createWalletTest({}, fixture);
    });
  });

  describe('addToAllowlist', function () {
    it('Should add when send from allowListOperator', async function () {
      const fixture = await loadFixture(deployFixture);

      const wallet = await createWalletTest({}, fixture);
      await addToAllowListTest({ wallet }, fixture);
    });
  });

  describe('removeFromAllowlist', function () {
    it('Should remove when send from allowListOperator', async function () {
      const fixture = await loadFixture(deployFixture);

      const wallet = await createWalletTest({}, fixture);
      await addToAllowListTest({ wallet }, fixture);
      await removeFromAllowListTest({ wallet }, fixture);
    });
  });

  describe('executeTest', function () {
    it('Execute regular eth send', async function () {
      const fixture = await loadFixture(deployFixture);

      const wallet = await createWalletTest({}, fixture);
      await executeTest(
        { wallet, to: fixture.otherAccounts[0].account.address },
        fixture,
      );
    });

    it('Execute when selector is blacklisted', async function () {
      const fixture = await loadFixture(deployFixture);

      const wallet = await createWalletTest({}, fixture);
      await addToAllowListTest({ wallet }, fixture);
      await blacklistTest(
        {
          wallet,
          to: fixture.otherAccounts[0].account.address,
          selector: '0x11112222',
        },
        fixture,
      );
      await executeTest(
        {
          wallet,
          to: fixture.otherAccounts[0].account.address,
          calldata: '0x11112222',
        },
        fixture,
        {
          revertedWith: 'CW: func is blacklisted',
        },
      );
    });
  });
  describe('addToAutoExecute', function () {
    it('Call from owner', async function () {
      const fixture = await loadFixture(deployFixture);

      const wallet = await createWalletTest({}, fixture);
      await setBalance(wallet.address, parseUnits('1', 18));
      await addToAutoExecuteTest(
        {
          to: fixture.otherAccounts[0].account.address,
          wallet,
        },
        fixture,
      );
    });
  });

  describe('checkUpkeep', function () {
    it('Call when upkeep is not needed', async function () {
      const fixture = await loadFixture(deployFixture);

      const wallet = await createWalletTest({}, fixture);
      await setBalance(wallet.address, parseUnits('1', 18));
      await addToAutoExecuteTest(
        {
          to: fixture.otherAccounts[0].account.address,
          wallet,
        },
        fixture,
      );
      const res = await wallet.read.checkUpkeep(['0x']);
      expect(res[0]).eq(false);
    });

    it('Call when upkeep is needed', async function () {
      const fixture = await loadFixture(deployFixture);

      const wallet = await createWalletTest({}, fixture);
      await setBalance(wallet.address, parseUnits('1', 18));
      await addToAutoExecuteTest(
        {
          to: fixture.otherAccounts[0].account.address,
          wallet,
        },
        fixture,
      );

      await time.increase(3700);
      const res = await wallet.read.checkUpkeep(['0x']);
      expect(res[0]).eq(true);
    });
  });

  describe('performUpkeep', function () {
    it('Call when upkeep is needed', async function () {
      const fixture = await loadFixture(deployFixture);

      const wallet = await createWalletTest({}, fixture);
      await setBalance(wallet.address, parseUnits('1', 18));
      await addToAutoExecuteTest(
        {
          to: fixture.otherAccounts[0].account.address,
          wallet,
        },
        fixture,
      );

      await time.increase(3700);

      await performUpkeep(
        { wallet, data: encodeAbiParameters([{ type: 'uint256' }], [1n]) },
        fixture,
      );
    });
  });
});
