import { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers';
import { expect } from 'chai';
import hre, { ethers } from 'hardhat';
import {
  GnosisSafe,
  GnosisSafeProxyFactory,
  LinearERC721VotingV2,
  LinearERC721VotingV2__factory,
  Azorius,
  Azorius__factory,
  ModuleProxyFactory,
  MockERC721,
  MockERC721__factory,
  GnosisSafeL2__factory,
  GnosisSafe__factory,
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

describe('Safe with Azorius module and linearERC721VotingV2', () => {
  const abiCoder = new ethers.AbiCoder();

  // Deployed contracts
  let gnosisSafe: GnosisSafe;
  let azorius: Azorius;
  let azoriusMastercopy: Azorius;
  let linearERC721Voting: LinearERC721VotingV2;
  let linearERC721VotingMastercopy: LinearERC721VotingV2;
  let mockNFT1: MockERC721;
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

    gnosisSafe = GnosisSafe__factory.connect(predictedGnosisSafeAddress, deployer);

    // Deploy Mock NFTs
    mockNFT1 = await new MockERC721__factory(deployer).deploy();

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

    azorius = Azorius__factory.connect(predictedAzoriusAddress, deployer);

    // Deploy Linear ERC721 Voting Mastercopy
    linearERC721VotingMastercopy = await new LinearERC721VotingV2__factory(deployer).deploy();

    const linearERC721VotingSetupCalldata =
      // eslint-disable-next-line camelcase
      LinearERC721VotingV2__factory.createInterface().encodeFunctionData('setUp', [
        abiCoder.encode(
          [
            'address',
            'address[]',
            'uint256[]',
            'address',
            'uint32',
            'uint256',
            'uint256',
            'uint256',
          ],
          [
            gnosisSafeOwner.address, // owner
            [await mockNFT1.getAddress()], // NFT addresses
            [1], // NFT weights
            await azorius.getAddress(), // Azorius module
            60, // voting period in blocks
            2, // quorom threshold
            2, // proposer threshold
            500000, // basis numerator, denominator is 1,000,000, so basis percentage is 50% (simple majority)
          ],
        ),
      ]);

    await moduleProxyFactory.deployModule(
      await linearERC721VotingMastercopy.getAddress(),
      linearERC721VotingSetupCalldata,
      '10031021',
    );

    const predictedlinearERC721VotingAddress = await calculateProxyAddress(
      moduleProxyFactory,
      await linearERC721VotingMastercopy.getAddress(),
      linearERC721VotingSetupCalldata,
      '10031021',
    );

    linearERC721Voting = LinearERC721VotingV2__factory.connect(
      predictedlinearERC721VotingAddress,
      deployer,
    );

    // Enable the Linear Voting strategy on Azorius
    await azorius.connect(gnosisSafeOwner).enableStrategy(await linearERC721Voting.getAddress());

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
    expect(await linearERC721Voting.getVersion()).to.eq(2);
  });
});
