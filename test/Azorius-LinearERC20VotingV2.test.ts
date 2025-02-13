import { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers';
import { expect } from 'chai';
import hre, { ethers } from 'hardhat';

import {
  GnosisSafe,
  GnosisSafeProxyFactory,
  LinearERC20VotingV2,
  LinearERC20VotingV2__factory,
  Azorius,
  Azorius__factory,
  VotesERC20,
  VotesERC20__factory,
  ModuleProxyFactory,
  GnosisSafeL2__factory,
} from '../typechain-types';

import {
  getGnosisSafeL2Singleton,
  getGnosisSafeProxyFactory,
  getModuleProxyFactory,
} from './GlobalSafeDeployments.test';
import {
  buildSignatureBytes,
  buildSafeTransaction,
  safeSignTypedData,
  predictGnosisSafeAddress,
  calculateProxyAddress,
} from './helpers';

describe('Safe with Azorius module and linearERC20VotingV2', () => {
  // Deployed contracts
  let gnosisSafe: GnosisSafe;
  let azorius: Azorius;
  let azoriusMastercopy: Azorius;
  let linearERC20Voting: LinearERC20VotingV2;
  let linearERC20VotingMastercopy: LinearERC20VotingV2;
  let votesERC20Mastercopy: VotesERC20;
  let votesERC20: VotesERC20;
  let gnosisSafeProxyFactory: GnosisSafeProxyFactory;
  let moduleProxyFactory: ModuleProxyFactory;

  // Wallets
  let deployer: SignerWithAddress;
  let gnosisSafeOwner: SignerWithAddress;

  // Gnosis
  let createGnosisSetupCalldata: string;

  const saltNum = BigInt('0x856d90216588f9ffc124d1480a440e1c012c7a816952bc968d737bae5d4e139c');

  beforeEach(async () => {
    gnosisSafeProxyFactory = getGnosisSafeProxyFactory();
    moduleProxyFactory = getModuleProxyFactory();
    const gnosisSafeL2Singleton = getGnosisSafeL2Singleton();

    const abiCoder = new ethers.AbiCoder();

    // Get the signer accounts
    [deployer, gnosisSafeOwner] = await hre.ethers.getSigners();

    createGnosisSetupCalldata =
      // eslint-disable-next-line camelcase
      GnosisSafeL2__factory.createInterface().encodeFunctionData('setup', [
        [gnosisSafeOwner.address],
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

    // Deploy Gnosis Safe
    await gnosisSafeProxyFactory.createProxyWithNonce(
      await gnosisSafeL2Singleton.getAddress(),
      createGnosisSetupCalldata,
      saltNum,
    );

    gnosisSafe = await hre.ethers.getContractAt('GnosisSafe', predictedGnosisSafeAddress);

    // Deploy Votes ERC-20 mastercopy contract
    votesERC20Mastercopy = await new VotesERC20__factory(deployer).deploy();

    const votesERC20SetupCalldata =
      // eslint-disable-next-line camelcase
      VotesERC20__factory.createInterface().encodeFunctionData('setUp', [
        abiCoder.encode(
          ['string', 'string', 'address[]', 'uint256[]'],
          ['DCNT', 'DCNT', [await gnosisSafe.getAddress()], [100]],
        ),
      ]);

    await moduleProxyFactory.deployModule(
      await votesERC20Mastercopy.getAddress(),
      votesERC20SetupCalldata,
      '10031021',
    );

    const predictedVotesERC20Address = await calculateProxyAddress(
      moduleProxyFactory,
      await votesERC20Mastercopy.getAddress(),
      votesERC20SetupCalldata,
      '10031021',
    );

    votesERC20 = await hre.ethers.getContractAt('VotesERC20', predictedVotesERC20Address);

    // Deploy Azorius module
    azoriusMastercopy = await new Azorius__factory(deployer).deploy();

    const azoriusSetupCalldata =
      // eslint-disable-next-line camelcase
      Azorius__factory.createInterface().encodeFunctionData('setUp', [
        abiCoder.encode(
          ['address', 'address', 'address', 'address[]', 'uint32', 'uint32'],
          [
            gnosisSafeOwner.address,
            await gnosisSafe.getAddress(),
            await gnosisSafe.getAddress(),
            [],
            60, // timelock period in blocks
            60, // execution period in blocks
          ],
        ),
      ]);

    await moduleProxyFactory.deployModule(
      await azoriusMastercopy.getAddress(),
      azoriusSetupCalldata,
      '10031021',
    );

    const predictedAzoriusAddress = await calculateProxyAddress(
      moduleProxyFactory,
      await azoriusMastercopy.getAddress(),
      azoriusSetupCalldata,
      '10031021',
    );

    azorius = await hre.ethers.getContractAt('Azorius', predictedAzoriusAddress);

    // Deploy Linear ERC20 Voting Mastercopy
    linearERC20VotingMastercopy = await new LinearERC20VotingV2__factory(deployer).deploy();

    const linearERC20VotingSetupCalldata =
      // eslint-disable-next-line camelcase
      LinearERC20VotingV2__factory.createInterface().encodeFunctionData('setUp', [
        abiCoder.encode(
          ['address', 'address', 'address', 'uint32', 'uint256', 'uint256', 'uint256'],
          [
            gnosisSafeOwner.address, // owner
            await votesERC20.getAddress(), // governance token
            await azorius.getAddress(), // Azorius module
            60, // voting period in blocks
            300, // proposer weight
            500000, // quorom numerator, denominator is 1,000,000, so quorum percentage is 50%
            500000, // basis numerator, denominator is 1,000,000, so basis percentage is 50% (simple majority)
          ],
        ),
      ]);

    await moduleProxyFactory.deployModule(
      await linearERC20VotingMastercopy.getAddress(),
      linearERC20VotingSetupCalldata,
      '10031021',
    );

    const predictedLinearERC20VotingAddress = await calculateProxyAddress(
      moduleProxyFactory,
      await linearERC20VotingMastercopy.getAddress(),
      linearERC20VotingSetupCalldata,
      '10031021',
    );

    linearERC20Voting = await hre.ethers.getContractAt(
      'LinearERC20VotingV2',
      predictedLinearERC20VotingAddress,
    );

    // Enable the Linear Voting strategy on Azorius
    await azorius.connect(gnosisSafeOwner).enableStrategy(await linearERC20Voting.getAddress());

    // Create transaction on Gnosis Safe to setup Azorius module
    const enableAzoriusModuleData = gnosisSafe.interface.encodeFunctionData('enableModule', [
      await azorius.getAddress(),
    ]);

    const enableAzoriusModuleTx = buildSafeTransaction({
      to: await gnosisSafe.getAddress(),
      data: enableAzoriusModuleData,
      safeTxGas: 1000000,
      nonce: await gnosisSafe.nonce(),
    });

    const sigs = [await safeSignTypedData(gnosisSafeOwner, gnosisSafe, enableAzoriusModuleTx)];

    const signatureBytes = buildSignatureBytes(sigs);

    // Execute transaction that adds the Azorius module to the Safe
    await expect(
      gnosisSafe.execTransaction(
        enableAzoriusModuleTx.to,
        enableAzoriusModuleTx.value,
        enableAzoriusModuleTx.data,
        enableAzoriusModuleTx.operation,
        enableAzoriusModuleTx.safeTxGas,
        enableAzoriusModuleTx.baseGas,
        enableAzoriusModuleTx.gasPrice,
        enableAzoriusModuleTx.gasToken,
        enableAzoriusModuleTx.refundReceiver,
        signatureBytes,
      ),
    ).to.emit(gnosisSafe, 'ExecutionSuccess');
  });

  it('Gets correctly initialized with version 2', async () => {
    expect(await linearERC20Voting.getVersion()).to.eq(2);
  });
});
