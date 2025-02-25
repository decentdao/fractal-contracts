import { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers';
import { expect } from 'chai';
import hre, { ethers } from 'hardhat';
import {
  AzoriusV1__factory,
  FractalModuleV1,
  FractalModuleV1__factory,
  GnosisSafeL2,
  GnosisSafeL2__factory,
  GnosisSafeProxyFactory,
  ModuleProxyFactory,
  MultiSendCallOnly,
  MultiSendCallOnly__factory,
  MultisigFreezeGuardV1,
  MultisigFreezeGuardV1__factory,
} from '../../typechain-types';
import {
  getGnosisSafeL2Singleton,
  getGnosisSafeProxyFactory,
  getModuleProxyFactory,
  getMultiSendCallOnly,
} from '../global/GlobalSafeDeployments.test';
import {
  calculateProxyAddress,
  predictGnosisSafeAddress,
  buildContractCall,
  MetaTransaction,
  encodeMultiSend,
} from '../helpers';

describe('Atomic Gnosis Safe Deployment', () => {
  // Factories
  let gnosisSafeProxyFactory: GnosisSafeProxyFactory;

  // Deployed contracts
  let gnosisSafeL2Singleton: GnosisSafeL2;
  let gnosisSafe: GnosisSafeL2;
  let moduleProxyFactory: ModuleProxyFactory;
  let multiSendCallOnly: MultiSendCallOnly;
  let freezeGuard: MultisigFreezeGuardV1;
  let freezeGuardImplementation: MultisigFreezeGuardV1;
  let fractalModuleSingleton: FractalModuleV1;
  let fractalModule: FractalModuleV1;

  // Predicted Contracts
  let predictedFractalModule: string;

  // Wallets
  let deployer: SignerWithAddress;
  let owner1: SignerWithAddress;
  let owner2: SignerWithAddress;
  let owner3: SignerWithAddress;

  const abiCoder = new hre.ethers.AbiCoder(); // encode data
  let createGnosisSetupCalldata: string;
  let freezeGuardFactoryInit: string;
  let setModuleCalldata: string;
  let sigs: string;

  const threshold = 2;
  let predictedFreezeGuard: string;
  const saltNum = BigInt('0x856d90216588f9ffc124d1480a440e1c012c7a816952bc968d737bae5d4e139c');

  beforeEach(async () => {
    gnosisSafeProxyFactory = getGnosisSafeProxyFactory();
    moduleProxyFactory = getModuleProxyFactory();
    multiSendCallOnly = getMultiSendCallOnly();
    gnosisSafeL2Singleton = getGnosisSafeL2Singleton();

    [deployer, owner1, owner2, owner3] = await hre.ethers.getSigners();

    /// ////////////////// GNOSIS //////////////////
    // SETUP GnosisSafe
    createGnosisSetupCalldata =
      // eslint-disable-next-line camelcase
      GnosisSafeL2__factory.createInterface().encodeFunctionData('setup', [
        [owner1.address, owner2.address, owner3.address, await multiSendCallOnly.getAddress()],
        1,
        ethers.ZeroAddress,
        ethers.ZeroHash,
        ethers.ZeroAddress,
        ethers.ZeroAddress,
        0,
        ethers.ZeroAddress,
      ]);

    const predictedGnosisSafeAddress = await predictGnosisSafeAddress(
      createGnosisSetupCalldata,
      saltNum,
      await gnosisSafeL2Singleton.getAddress(),
      gnosisSafeProxyFactory,
    );

    // Get Gnosis Safe contract
    // eslint-disable-next-line camelcase
    gnosisSafe = GnosisSafeL2__factory.connect(predictedGnosisSafeAddress, deployer);

    /// /////////////  GUARD ///////////////////
    // DEPLOY GUARD
    freezeGuardImplementation = await new MultisigFreezeGuardV1__factory(deployer).deploy();
    freezeGuardFactoryInit =
      // eslint-disable-next-line camelcase
      MultisigFreezeGuardV1__factory.createInterface().encodeFunctionData('setUp', [
        abiCoder.encode(
          ['uint256', 'uint256', 'address', 'address', 'address'],
          [10, 20, owner1.address, owner1.address, await gnosisSafe.getAddress()],
        ),
      ]);

    predictedFreezeGuard = await calculateProxyAddress(
      moduleProxyFactory,
      await freezeGuardImplementation.getAddress(),
      freezeGuardFactoryInit,
      '10031021',
    );

    freezeGuard = MultisigFreezeGuardV1__factory.connect(predictedFreezeGuard, deployer);

    /// /////////////// MODULE ////////////////
    // DEPLOY Fractal Module
    fractalModuleSingleton = await new FractalModuleV1__factory(deployer).deploy();

    // SETUP Module
    setModuleCalldata =
      // eslint-disable-next-line camelcase
      FractalModuleV1__factory.createInterface().encodeFunctionData('setUp', [
        abiCoder.encode(
          ['address', 'address', 'address', 'address[]'],
          [
            owner1.address,
            await gnosisSafe.getAddress(),
            await gnosisSafe.getAddress(),
            [owner2.address],
          ],
        ),
      ]);

    predictedFractalModule = await calculateProxyAddress(
      moduleProxyFactory,
      await fractalModuleSingleton.getAddress(),
      setModuleCalldata,
      '10031021',
    );

    fractalModule = FractalModuleV1__factory.connect(predictedFractalModule, deployer);

    // TX Array
    sigs =
      '0x000000000000000000000000' +
      (await multiSendCallOnly.getAddress()).slice(2) +
      '0000000000000000000000000000000000000000000000000000000000000000' +
      '01';
  });

  describe('Atomic Gnosis Safe Deployment', () => {
    it('Setup Fractal Module w/ ModuleProxyCreationEvent', async () => {
      const txs: MetaTransaction[] = [
        await buildContractCall(
          gnosisSafeProxyFactory,
          'createProxyWithNonce',
          [await gnosisSafeL2Singleton.getAddress(), createGnosisSetupCalldata, saltNum],
          0,
          false,
        ),
        await buildContractCall(
          moduleProxyFactory,
          'deployModule',
          [await fractalModuleSingleton.getAddress(), setModuleCalldata, '10031021'],
          0,
          false,
        ),
      ];
      const safeTx = encodeMultiSend(txs);
      await expect(multiSendCallOnly.multiSend(safeTx))
        .to.emit(moduleProxyFactory, 'ModuleProxyCreation')
        .withArgs(predictedFractalModule, await fractalModuleSingleton.getAddress());

      expect(await fractalModule.avatar()).eq(await gnosisSafe.getAddress());
      expect(await fractalModule.getFunction('target')()).eq(await gnosisSafe.getAddress());
      expect(await fractalModule.owner()).eq(owner1.address);
    });

    it('Setup FreezeGuard w/ ModuleProxyCreationEvent', async () => {
      const txs: MetaTransaction[] = [
        await buildContractCall(
          gnosisSafeProxyFactory,
          'createProxyWithNonce',
          [await gnosisSafeL2Singleton.getAddress(), createGnosisSetupCalldata, saltNum],
          0,
          false,
        ),
        await buildContractCall(
          moduleProxyFactory,
          'deployModule',
          [await freezeGuardImplementation.getAddress(), freezeGuardFactoryInit, '10031021'],
          0,
          false,
        ),
      ];
      const safeTx = encodeMultiSend(txs);
      await expect(multiSendCallOnly.multiSend(safeTx))
        .to.emit(moduleProxyFactory, 'ModuleProxyCreation')
        .withArgs(predictedFreezeGuard, await freezeGuardImplementation.getAddress());
      expect(await freezeGuard.timelockPeriod()).eq(10);
      expect(await freezeGuard.freezeVoting()).eq(owner1.address);
      expect(await freezeGuard.childGnosisSafe()).eq(await gnosisSafe.getAddress());
    });

    it('Setup Azorius Module w/ ModuleProxyCreationEvent', async () => {
      const VOTING_STRATEGIES_TO_DEPLOY: string[] = [];
      const encodedInitAzoriusData = abiCoder.encode(
        ['address', 'address', 'address', 'address[]', 'uint32', 'uint32'],
        [
          await gnosisSafe.getAddress(),
          await gnosisSafe.getAddress(),
          await gnosisSafe.getAddress(),
          VOTING_STRATEGIES_TO_DEPLOY,
          0,
          0,
        ],
      );
      const encodedSetupAzoriusData =
        // eslint-disable-next-line camelcase
        AzoriusV1__factory.createInterface().encodeFunctionData('setUp', [encodedInitAzoriusData]);

      const azoriusSingleton = await new AzoriusV1__factory(deployer).deploy();

      const predictedAzoriusModule = await calculateProxyAddress(
        moduleProxyFactory,
        await azoriusSingleton.getAddress(),
        encodedSetupAzoriusData,
        '10031021',
      );

      // eslint-disable-next-line camelcase
      const azoriusContract = AzoriusV1__factory.connect(predictedAzoriusModule, deployer);

      const txs: MetaTransaction[] = [
        await buildContractCall(
          gnosisSafeProxyFactory,
          'createProxyWithNonce',
          [await gnosisSafeL2Singleton.getAddress(), createGnosisSetupCalldata, saltNum],
          0,
          false,
        ),
        await buildContractCall(
          moduleProxyFactory,
          'deployModule',
          [await azoriusSingleton.getAddress(), encodedSetupAzoriusData, '10031021'],
          0,
          false,
        ),
      ];
      const safeTx = encodeMultiSend(txs);

      const tx = await multiSendCallOnly.multiSend(safeTx);

      await expect(tx)
        .to.emit(moduleProxyFactory, 'ModuleProxyCreation')
        .withArgs(predictedAzoriusModule, await azoriusSingleton.getAddress());

      expect(await azoriusContract.avatar()).eq(await gnosisSafe.getAddress());
      expect(await azoriusContract.getFunction('target')()).eq(await gnosisSafe.getAddress());
      expect(await azoriusContract.owner()).eq(await gnosisSafe.getAddress());
    });

    it('Setup Module w/ enabledModule event', async () => {
      const internalTxs: MetaTransaction[] = [
        await buildContractCall(
          gnosisSafe,
          'enableModule',
          [await fractalModule.getAddress()],
          0,
          false,
        ),
      ];
      const safeInternalTx = encodeMultiSend(internalTxs);
      const txs: MetaTransaction[] = [
        await buildContractCall(
          gnosisSafeProxyFactory,
          'createProxyWithNonce',
          [await gnosisSafeL2Singleton.getAddress(), createGnosisSetupCalldata, saltNum],
          0,
          false,
        ),
        await buildContractCall(
          moduleProxyFactory,
          'deployModule',
          [await fractalModuleSingleton.getAddress(), setModuleCalldata, '10031021'],
          0,
          false,
        ),
        await buildContractCall(
          moduleProxyFactory,
          'deployModule',
          [await freezeGuardImplementation.getAddress(), freezeGuardFactoryInit, '10031021'],
          0,
          false,
        ),
        await buildContractCall(
          gnosisSafe,
          'execTransaction',
          [
            await multiSendCallOnly.getAddress(), // to
            '0', // value
            // eslint-disable-next-line camelcase
            MultiSendCallOnly__factory.createInterface().encodeFunctionData('multiSend', [
              safeInternalTx,
            ]), // calldata
            '1', // operation
            '0', // tx gas
            '0', // base gas
            '0', // gas price
            ethers.ZeroAddress, // gas token
            ethers.ZeroAddress, // receiver
            sigs, // sigs
          ],
          0,
          false,
        ),
      ];
      const safeTx = encodeMultiSend(txs);
      await expect(multiSendCallOnly.multiSend(safeTx))
        .to.emit(gnosisSafe, 'EnabledModule')
        .withArgs(await fractalModule.getAddress());
      expect(await gnosisSafe.isModuleEnabled(await fractalModule.getAddress())).to.eq(true);
    });

    it('Setup AzoriusModule w/ enabledModule event', async () => {
      const VOTING_STRATEGIES_TO_DEPLOY: string[] = []; // @todo pass expected addresses for voting strategies
      const encodedInitAzoriusData = abiCoder.encode(
        ['address', 'address', 'address', 'address[]', 'uint32', 'uint32'],
        [
          await gnosisSafe.getAddress(),
          await gnosisSafe.getAddress(),
          await gnosisSafe.getAddress(),
          VOTING_STRATEGIES_TO_DEPLOY,
          0,
          0,
        ],
      );
      const encodedSetupAzoriusData =
        // eslint-disable-next-line camelcase
        AzoriusV1__factory.createInterface().encodeFunctionData('setUp', [encodedInitAzoriusData]);

      const azoriusSingleton = await new AzoriusV1__factory(deployer).deploy();

      const predictedAzoriusModule = await calculateProxyAddress(
        moduleProxyFactory,
        await azoriusSingleton.getAddress(),
        encodedSetupAzoriusData,
        '10031021',
      );

      // eslint-disable-next-line camelcase
      const azoriusContract = AzoriusV1__factory.connect(predictedAzoriusModule, deployer);

      const internalTxs: MetaTransaction[] = [
        await buildContractCall(
          gnosisSafe,
          'enableModule',
          [await fractalModule.getAddress()],
          0,
          false,
        ),
        await buildContractCall(
          gnosisSafe,
          'enableModule',
          [await azoriusContract.getAddress()],
          0,
          false,
        ),
      ];
      const safeInternalTx = encodeMultiSend(internalTxs);
      const txs: MetaTransaction[] = [
        await buildContractCall(
          gnosisSafeProxyFactory,
          'createProxyWithNonce',
          [await gnosisSafeL2Singleton.getAddress(), createGnosisSetupCalldata, saltNum],
          0,
          false,
        ),
        await buildContractCall(
          moduleProxyFactory,
          'deployModule',
          [await fractalModuleSingleton.getAddress(), setModuleCalldata, '10031021'],
          0,
          false,
        ),
        await buildContractCall(
          moduleProxyFactory,
          'deployModule',
          [await freezeGuardImplementation.getAddress(), freezeGuardFactoryInit, '10031021'],
          0,
          false,
        ),
        await buildContractCall(
          moduleProxyFactory,
          'deployModule',
          [await azoriusSingleton.getAddress(), encodedSetupAzoriusData, '10031021'],
          0,
          false,
        ),
        await buildContractCall(
          gnosisSafe,
          'execTransaction',
          [
            await multiSendCallOnly.getAddress(), // to
            '0', // value
            // eslint-disable-next-line camelcase
            MultiSendCallOnly__factory.createInterface().encodeFunctionData('multiSend', [
              safeInternalTx,
            ]), // calldata
            '1', // operation
            '0', // tx gas
            '0', // base gas
            '0', // gas price
            ethers.ZeroAddress, // gas token
            ethers.ZeroAddress, // receiver
            sigs, // sigs
          ],
          0,
          false,
        ),
      ];
      const safeTx = encodeMultiSend(txs);
      await expect(multiSendCallOnly.multiSend(safeTx))
        .to.emit(gnosisSafe, 'EnabledModule')
        .withArgs(await azoriusContract.getAddress());
      expect(await gnosisSafe.isModuleEnabled(await azoriusContract.getAddress())).to.eq(true);
    });

    it('Setup Guard w/ changeGuard event', async () => {
      const internalTxs: MetaTransaction[] = [
        await buildContractCall(gnosisSafe, 'setGuard', [await freezeGuard.getAddress()], 0, false),
      ];
      const safeInternalTx = encodeMultiSend(internalTxs);
      const txs: MetaTransaction[] = [
        await buildContractCall(
          gnosisSafeProxyFactory,
          'createProxyWithNonce',
          [await gnosisSafeL2Singleton.getAddress(), createGnosisSetupCalldata, saltNum],
          0,
          false,
        ),
        await buildContractCall(
          moduleProxyFactory,
          'deployModule',
          [await fractalModuleSingleton.getAddress(), setModuleCalldata, '10031021'],
          0,
          false,
        ),
        await buildContractCall(
          moduleProxyFactory,
          'deployModule',
          [await freezeGuardImplementation.getAddress(), freezeGuardFactoryInit, '10031021'],
          0,
          false,
        ),
        await buildContractCall(
          gnosisSafe,
          'execTransaction',
          [
            await multiSendCallOnly.getAddress(), // to
            '0', // value
            // eslint-disable-next-line camelcase
            MultiSendCallOnly__factory.createInterface().encodeFunctionData('multiSend', [
              safeInternalTx,
            ]), // calldata
            '1', // operation
            '0', // tx gas
            '0', // base gas
            '0', // gas price
            ethers.ZeroAddress, // gas token
            ethers.ZeroAddress, // receiver
            sigs, // sigs
          ],
          0,
          false,
        ),
      ];
      const safeTx = encodeMultiSend(txs);
      await expect(multiSendCallOnly.multiSend(safeTx))
        .to.emit(gnosisSafe, 'ChangedGuard')
        .withArgs(await freezeGuard.getAddress());
    });

    it('Setup Gnosis Safe w/ removedOwner event', async () => {
      const internalTxs: MetaTransaction[] = [
        await buildContractCall(
          gnosisSafe,
          'removeOwner',
          [owner3.address, await multiSendCallOnly.getAddress(), threshold],
          0,
          false,
        ),
      ];
      const safeInternalTx = encodeMultiSend(internalTxs);
      const txs: MetaTransaction[] = [
        await buildContractCall(
          gnosisSafeProxyFactory,
          'createProxyWithNonce',
          [await gnosisSafeL2Singleton.getAddress(), createGnosisSetupCalldata, saltNum],
          0,
          false,
        ),
        await buildContractCall(
          moduleProxyFactory,
          'deployModule',
          [await fractalModuleSingleton.getAddress(), setModuleCalldata, '10031021'],
          0,
          false,
        ),
        await buildContractCall(
          moduleProxyFactory,
          'deployModule',
          [await freezeGuardImplementation.getAddress(), freezeGuardFactoryInit, '10031021'],
          0,
          false,
        ),
        await buildContractCall(
          gnosisSafe,
          'execTransaction',
          [
            await multiSendCallOnly.getAddress(), // to
            '0', // value
            // eslint-disable-next-line camelcase
            MultiSendCallOnly__factory.createInterface().encodeFunctionData('multiSend', [
              safeInternalTx,
            ]), // calldata
            '1', // operation
            '0', // tx gas
            '0', // base gas
            '0', // gas price
            ethers.ZeroAddress, // gas token
            ethers.ZeroAddress, // receiver
            sigs, // sigs
          ],
          0,
          false,
        ),
      ];
      const safeTx = encodeMultiSend(txs);
      await expect(multiSendCallOnly.multiSend(safeTx))
        .to.emit(gnosisSafe, 'RemovedOwner')
        .withArgs(await multiSendCallOnly.getAddress());

      expect(await gnosisSafe.isOwner(owner1.address)).eq(true);
      expect(await gnosisSafe.isOwner(owner2.address)).eq(true);
      expect(await gnosisSafe.isOwner(owner3.address)).eq(true);
      expect(await gnosisSafe.isOwner(await multiSendCallOnly.getAddress())).eq(false);
      expect(await gnosisSafe.getThreshold()).eq(threshold);
    });
  });

  describe('Version', function () {
    it('Fractal module should have a version', async function () {
      const txs: MetaTransaction[] = [
        await buildContractCall(
          gnosisSafeProxyFactory,
          'createProxyWithNonce',
          [await gnosisSafeL2Singleton.getAddress(), createGnosisSetupCalldata, saltNum],
          0,
          false,
        ),
        await buildContractCall(
          moduleProxyFactory,
          'deployModule',
          [await fractalModuleSingleton.getAddress(), setModuleCalldata, '10031021'],
          0,
          false,
        ),
      ];
      const safeTx = encodeMultiSend(txs);
      await multiSendCallOnly.multiSend(safeTx);

      const version = await fractalModule.getVersion();
      void expect(version).to.equal(1);
    });

    it('Freeze guard should have a version', async function () {
      const version = await freezeGuardImplementation.getVersion();
      void expect(version).to.equal(1);
    });
  });
});
