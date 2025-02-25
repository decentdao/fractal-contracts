import { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers';
import { expect } from 'chai';
import hre, { ethers } from 'hardhat';

import {
  GnosisSafe,
  GnosisSafeProxyFactory,
  LinearERC20VotingV1,
  LinearERC20VotingV1__factory,
  AzoriusV1,
  AzoriusV1__factory,
  AzoriusFreezeGuardV1,
  AzoriusFreezeGuardV1__factory,
  ERC20FreezeVotingV1,
  ERC20FreezeVotingV1__factory,
  VotesERC20V1,
  VotesERC20V1__factory,
  ModuleProxyFactory,
  GnosisSafeL2__factory,
} from '../../typechain-types';

import {
  getGnosisSafeL2Singleton,
  getGnosisSafeProxyFactory,
  getModuleProxyFactory,
} from '../global/GlobalSafeDeployments.test';
import {
  buildSignatureBytes,
  buildSafeTransaction,
  safeSignTypedData,
  predictGnosisSafeAddress,
  calculateProxyAddress,
} from '../helpers';

import time from '../time';

describe('Azorius Child DAO with Azorius Parent', () => {
  // Deployed contracts
  let childGnosisSafe: GnosisSafe;
  let freezeGuardMastercopy: AzoriusFreezeGuardV1;
  let freezeGuard: AzoriusFreezeGuardV1;
  let azoriusMastercopy: AzoriusV1;
  let azoriusModule: AzoriusV1;
  let linearERC20Voting: LinearERC20VotingV1;
  let linearERC20VotingMastercopy: LinearERC20VotingV1;
  let freezeVotingMastercopy: ERC20FreezeVotingV1;
  let freezeVoting: ERC20FreezeVotingV1;
  let votesERC20Mastercopy: VotesERC20V1;
  let parentVotesERC20: VotesERC20V1;
  let childVotesERC20: VotesERC20V1;
  let gnosisSafeProxyFactory: GnosisSafeProxyFactory;
  let moduleProxyFactory: ModuleProxyFactory;

  // Wallets
  let deployer: SignerWithAddress;
  let childSafeOwner: SignerWithAddress;
  let parentTokenHolder1: SignerWithAddress;
  let parentTokenHolder2: SignerWithAddress;
  let childTokenHolder1: SignerWithAddress;
  let childTokenHolder2: SignerWithAddress;
  let mockParentDAO: SignerWithAddress;

  // Gnosis
  let createGnosisSetupCalldata: string;

  const saltNum = BigInt('0x856d90216588f9ffc124d1480a440e1c012c7a816952bc968d737bae5d4e139c');

  beforeEach(async () => {
    gnosisSafeProxyFactory = getGnosisSafeProxyFactory();
    moduleProxyFactory = getModuleProxyFactory();
    const gnosisSafeL2Singleton = getGnosisSafeL2Singleton();

    const abiCoder = new ethers.AbiCoder();

    // Get the signer accounts
    [
      deployer,
      childSafeOwner,
      parentTokenHolder1,
      parentTokenHolder2,
      childTokenHolder1,
      childTokenHolder2,
      mockParentDAO,
    ] = await hre.ethers.getSigners();

    createGnosisSetupCalldata =
      // eslint-disable-next-line camelcase
      GnosisSafeL2__factory.createInterface().encodeFunctionData('setup', [
        [childSafeOwner.address],
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

    childGnosisSafe = GnosisSafeL2__factory.connect(predictedGnosisSafeAddress, deployer);

    // Deploy Votes ERC20 Mastercopy
    votesERC20Mastercopy = await new VotesERC20V1__factory(deployer).deploy();

    const childVotesERC20SetupData =
      // eslint-disable-next-line camelcase
      VotesERC20V1__factory.createInterface().encodeFunctionData('setUp', [
        abiCoder.encode(
          ['string', 'string', 'address[]', 'uint256[]'],
          [
            'CHILD',
            'CHILD',
            [
              childTokenHolder1.address,
              childTokenHolder2.address,
              await childGnosisSafe.getAddress(),
            ],
            [100, 100, 100],
          ],
        ),
      ]);

    await moduleProxyFactory.deployModule(
      await votesERC20Mastercopy.getAddress(),
      childVotesERC20SetupData,
      '10031021',
    );

    const predictedChildVotesERC20Address = await calculateProxyAddress(
      moduleProxyFactory,
      await votesERC20Mastercopy.getAddress(),
      childVotesERC20SetupData,
      '10031021',
    );

    childVotesERC20 = VotesERC20V1__factory.connect(predictedChildVotesERC20Address, deployer);

    // Parent Votes ERC-20
    parentVotesERC20 = await new VotesERC20V1__factory(deployer).deploy();

    const parentVotesERC20SetupData =
      // eslint-disable-next-line camelcase
      VotesERC20V1__factory.createInterface().encodeFunctionData('setUp', [
        abiCoder.encode(
          ['string', 'string', 'address[]', 'uint256[]'],
          [
            'PARENT',
            'PARENT',
            [parentTokenHolder1.address, parentTokenHolder2.address],
            [100, 100],
          ],
        ),
      ]);

    await moduleProxyFactory.deployModule(
      await votesERC20Mastercopy.getAddress(),
      parentVotesERC20SetupData,
      '10031021',
    );

    const predictedParentVotesERC20Address = await calculateProxyAddress(
      moduleProxyFactory,
      await votesERC20Mastercopy.getAddress(),
      parentVotesERC20SetupData,
      '10031021',
    );

    parentVotesERC20 = VotesERC20V1__factory.connect(predictedParentVotesERC20Address, deployer);

    // Token holders delegate their votes to themselves
    await childVotesERC20.connect(childTokenHolder1).delegate(childTokenHolder1.address);
    await childVotesERC20.connect(childTokenHolder2).delegate(childTokenHolder2.address);
    await parentVotesERC20.connect(parentTokenHolder1).delegate(parentTokenHolder1.address);
    await parentVotesERC20.connect(parentTokenHolder2).delegate(parentTokenHolder2.address);

    // Deploy Azorius module
    azoriusMastercopy = await new AzoriusV1__factory(deployer).deploy();

    const azoriusSetupCalldata =
      // eslint-disable-next-line camelcase
      AzoriusV1__factory.createInterface().encodeFunctionData('setUp', [
        abiCoder.encode(
          ['address', 'address', 'address', 'address[]', 'uint32', 'uint32'],
          [
            mockParentDAO.address,
            await childGnosisSafe.getAddress(),
            await childGnosisSafe.getAddress(),
            [],
            60, // Timelock period in blocks
            60, // Execution period in blocks
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

    azoriusModule = AzoriusV1__factory.connect(predictedAzoriusAddress, deployer);

    // Deploy Linear ERC-20 Voting Strategy
    linearERC20VotingMastercopy = await new LinearERC20VotingV1__factory(deployer).deploy();

    const linearERC20VotingSetupCalldata =
      // eslint-disable-next-line camelcase
      LinearERC20VotingV1__factory.createInterface().encodeFunctionData('setUp', [
        abiCoder.encode(
          ['address', 'address', 'address', 'uint32', 'uint256', 'uint256', 'uint256'],
          [
            mockParentDAO.address, // owner
            await childVotesERC20.getAddress(), // governance token
            await azoriusModule.getAddress(), // Azorius module
            60, // voting period in blocks
            0, // proposer weight
            500000, // quorom numerator, denominator is 1,000,000
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

    linearERC20Voting = LinearERC20VotingV1__factory.connect(
      predictedLinearERC20VotingAddress,
      deployer,
    );

    // Enable the Linear Token Voting strategy on Azorius
    await azoriusModule.connect(mockParentDAO).enableStrategy(await linearERC20Voting.getAddress());

    // Deploy ERC20FreezeVoting contract
    freezeVotingMastercopy = await new ERC20FreezeVotingV1__factory(deployer).deploy();

    const freezeVotingSetupCalldata =
      // eslint-disable-next-line camelcase
      ERC20FreezeVotingV1__factory.createInterface().encodeFunctionData('setUp', [
        abiCoder.encode(
          ['address', 'uint256', 'uint32', 'uint32', 'address'],
          [
            mockParentDAO.address, // owner
            150, // freeze votes threshold
            10, // freeze proposal duration in blocks
            100, // freeze duration in blocks
            await parentVotesERC20.getAddress(),
          ],
        ),
      ]);

    await moduleProxyFactory.deployModule(
      await freezeVotingMastercopy.getAddress(),
      freezeVotingSetupCalldata,
      '10031021',
    );

    const predictedFreezeVotingAddress = await calculateProxyAddress(
      moduleProxyFactory,
      await freezeVotingMastercopy.getAddress(),
      freezeVotingSetupCalldata,
      '10031021',
    );

    freezeVoting = ERC20FreezeVotingV1__factory.connect(predictedFreezeVotingAddress, deployer);

    // Deploy and setUp Azorius Freeze Guard contract
    freezeGuardMastercopy = await new AzoriusFreezeGuardV1__factory(deployer).deploy();

    const freezeGuardSetupCalldata =
      // eslint-disable-next-line camelcase
      LinearERC20VotingV1__factory.createInterface().encodeFunctionData('setUp', [
        abiCoder.encode(
          ['address', 'address'],
          [
            mockParentDAO.address, // Owner
            await freezeVoting.getAddress(), // Freeze voting contract
          ],
        ),
      ]);

    await moduleProxyFactory.deployModule(
      await freezeGuardMastercopy.getAddress(),
      freezeGuardSetupCalldata,
      '10031021',
    );

    const predictedFreezeGuardAddress = await calculateProxyAddress(
      moduleProxyFactory,
      await freezeGuardMastercopy.getAddress(),
      freezeGuardSetupCalldata,
      '10031021',
    );

    freezeGuard = AzoriusFreezeGuardV1__factory.connect(predictedFreezeGuardAddress, deployer);

    // Set the Azorius Freeze Guard as the Guard on the Azorius Module
    await azoriusModule.connect(mockParentDAO).setGuard(await freezeGuard.getAddress());

    // Create transaction on Gnosis Safe to setup Azorius module
    const enableAzoriusModuleData = childGnosisSafe.interface.encodeFunctionData('enableModule', [
      await azoriusModule.getAddress(),
    ]);

    const enableAzoriusModuleTx = buildSafeTransaction({
      to: await childGnosisSafe.getAddress(),
      data: enableAzoriusModuleData,
      safeTxGas: 1000000,
      nonce: await childGnosisSafe.nonce(),
    });

    const sigs = [await safeSignTypedData(childSafeOwner, childGnosisSafe, enableAzoriusModuleTx)];

    const signatureBytes = buildSignatureBytes(sigs);

    // Execute transaction that adds the Azorius module to the Safe
    await expect(
      childGnosisSafe.execTransaction(
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
    ).to.emit(childGnosisSafe, 'ExecutionSuccess');

    // Gnosis Safe received the 1,000 tokens
    expect(await childVotesERC20.balanceOf(await childGnosisSafe.getAddress())).to.eq(100);
  });

  describe('FreezeGuard Functionality', () => {
    it('A proposal can be created and executed', async () => {
      // Create transaction to transfer tokens to the deployer
      const tokenTransferData = childVotesERC20.interface.encodeFunctionData('transfer', [
        deployer.address,
        10,
      ]);

      const proposalTransaction = {
        to: await childVotesERC20.getAddress(),
        value: 0n,
        data: tokenTransferData,
        operation: 0,
      };

      await azoriusModule.submitProposal(
        await linearERC20Voting.getAddress(),
        '0x',
        [proposalTransaction],
        '',
      );

      // Proposal is active
      expect(await azoriusModule.proposalState(0)).to.eq(0);

      // Both users vote in support of proposal
      await linearERC20Voting.connect(childTokenHolder1).vote(0, 1);
      await linearERC20Voting.connect(childTokenHolder2).vote(0, 1);

      // Increase time so that voting period has ended
      await time.advanceBlocks(60);

      // Proposal is timelocked
      expect(await azoriusModule.proposalState(0)).to.eq(1);

      // Increase time so that timelock period has ended
      await time.advanceBlocks(60);

      // Proposal is executable
      expect(await azoriusModule.proposalState(0)).to.eq(2);

      expect(await childVotesERC20.balanceOf(await childGnosisSafe.getAddress())).to.eq(100);
      expect(await childVotesERC20.balanceOf(deployer.address)).to.eq(0);

      // Execute the transaction
      await azoriusModule.executeProposal(
        0,
        [await childVotesERC20.getAddress()],
        [0],
        [tokenTransferData],
        [0],
      );

      // Proposal is executed
      expect(await azoriusModule.proposalState(0)).to.eq(3);

      expect(await childVotesERC20.balanceOf(await childGnosisSafe.getAddress())).to.eq(90);
      expect(await childVotesERC20.balanceOf(deployer.address)).to.eq(10);
    });

    it('A proposal containing multiple transactions can be created and executed', async () => {
      // Create transaction to transfer tokens to the deployer
      const tokenTransferData1 = childVotesERC20.interface.encodeFunctionData('transfer', [
        deployer.address,
        1,
      ]);

      const tokenTransferData2 = childVotesERC20.interface.encodeFunctionData('transfer', [
        deployer.address,
        2,
      ]);

      const tokenTransferData3 = childVotesERC20.interface.encodeFunctionData('transfer', [
        deployer.address,
        3,
      ]);

      const proposalTransactions = [
        {
          to: await childVotesERC20.getAddress(),
          value: 0n,
          data: tokenTransferData1,
          operation: 0,
        },
        {
          to: await childVotesERC20.getAddress(),
          value: 0n,
          data: tokenTransferData2,
          operation: 0,
        },
        {
          to: await childVotesERC20.getAddress(),
          value: 0n,
          data: tokenTransferData3,
          operation: 0,
        },
      ];

      await azoriusModule.submitProposal(
        await linearERC20Voting.getAddress(),
        '0x',
        proposalTransactions,
        '',
      );

      // Proposal is active
      expect(await azoriusModule.proposalState(0)).to.eq(0);

      // Both users vote in support of proposal
      await linearERC20Voting.connect(childTokenHolder1).vote(0, 1);
      await linearERC20Voting.connect(childTokenHolder2).vote(0, 1);

      // Increase time so that voting period has ended
      await time.advanceBlocks(60);

      // Increase time so that timelock period has ended
      await time.advanceBlocks(60);

      // Proposal is executable
      expect(await azoriusModule.proposalState(0)).to.eq(2);

      expect(await childVotesERC20.balanceOf(await childGnosisSafe.getAddress())).to.eq(100);
      expect(await childVotesERC20.balanceOf(deployer.address)).to.eq(0);

      // Execute the transaction
      await azoriusModule.executeProposal(
        0,
        [
          await childVotesERC20.getAddress(),
          await childVotesERC20.getAddress(),
          await childVotesERC20.getAddress(),
        ],
        [0, 0, 0],
        [tokenTransferData1, tokenTransferData2, tokenTransferData3],
        [0, 0, 0],
      );

      // Proposal is executed
      expect(await azoriusModule.proposalState(0)).to.eq(3);

      // Check that all three token transfer TX's were executed
      expect(await childVotesERC20.balanceOf(await childGnosisSafe.getAddress())).to.eq(94);
      expect(await childVotesERC20.balanceOf(deployer.address)).to.eq(6);
    });

    it('A frozen DAO cannot execute any transaction', async () => {
      // Create transaction to transfer tokens to the deployer
      const tokenTransferData1 = childVotesERC20.interface.encodeFunctionData('transfer', [
        deployer.address,
        10,
      ]);

      const tokenTransferData2 = childVotesERC20.interface.encodeFunctionData('transfer', [
        deployer.address,
        5,
      ]);

      const tokenTransferData3 = childVotesERC20.interface.encodeFunctionData('transfer', [
        deployer.address,
        4,
      ]);

      const proposalTransaction1 = {
        to: await childVotesERC20.getAddress(),
        value: 0n,
        data: tokenTransferData1,
        operation: 0,
      };

      const proposalTransaction2 = {
        to: await childVotesERC20.getAddress(),
        value: 0n,
        data: tokenTransferData2,
        operation: 0,
      };

      const proposalTransaction3 = {
        to: await childVotesERC20.getAddress(),
        value: 0n,
        data: tokenTransferData3,
        operation: 0,
      };

      await azoriusModule.submitProposal(
        await linearERC20Voting.getAddress(),
        '0x',
        [proposalTransaction1],
        '',
      );
      await azoriusModule.submitProposal(
        await linearERC20Voting.getAddress(),
        '0x',
        [proposalTransaction2],
        '',
      );
      await azoriusModule.submitProposal(
        await linearERC20Voting.getAddress(),
        '0x',
        [proposalTransaction3],
        '',
      );

      // Proposal is active
      expect(await azoriusModule.proposalState(0)).to.eq(0);
      expect(await azoriusModule.proposalState(1)).to.eq(0);
      expect(await azoriusModule.proposalState(2)).to.eq(0);

      // Both users vote in support of proposals
      await linearERC20Voting.connect(childTokenHolder1).vote(0, 1);
      await linearERC20Voting.connect(childTokenHolder2).vote(0, 1);

      await linearERC20Voting.connect(childTokenHolder1).vote(1, 1);
      await linearERC20Voting.connect(childTokenHolder2).vote(1, 1);

      await linearERC20Voting.connect(childTokenHolder1).vote(2, 1);
      await linearERC20Voting.connect(childTokenHolder2).vote(2, 1);

      // Increase time so that voting period has ended
      await time.advanceBlocks(60);

      // Proposal is timelocked
      expect(await azoriusModule.proposalState(0)).to.eq(1);
      expect(await azoriusModule.proposalState(1)).to.eq(1);
      expect(await azoriusModule.proposalState(2)).to.eq(1);

      expect(await freezeVoting.isFrozen()).to.eq(false);

      // Voters cast freeze votes
      await freezeVoting.connect(parentTokenHolder1).castFreezeVote();

      await freezeVoting.connect(parentTokenHolder2).castFreezeVote();

      expect(await freezeVoting.isFrozen()).to.eq(true);

      // Increase time so that timelock period has ended
      await time.advanceBlocks(60);

      // Proposals are executable
      expect(await azoriusModule.proposalState(0)).to.eq(2);
      expect(await azoriusModule.proposalState(1)).to.eq(2);
      expect(await azoriusModule.proposalState(2)).to.eq(2);

      // This proposal should fail due to freeze
      await expect(
        azoriusModule.executeProposal(
          0,
          [await childVotesERC20.getAddress()],
          [0],
          [tokenTransferData1],
          [0],
        ),
      ).to.be.revertedWithCustomError(freezeGuard, 'DAOFrozen()');

      // This proposal should fail due to freeze
      await expect(
        azoriusModule.executeProposal(
          1,
          [await childVotesERC20.getAddress()],
          [0],
          [tokenTransferData2],
          [0],
        ),
      ).to.be.revertedWithCustomError(freezeGuard, 'DAOFrozen()');

      // This proposal should fail due to freeze
      await expect(
        azoriusModule.executeProposal(
          2,
          [await childVotesERC20.getAddress()],
          [0],
          [tokenTransferData3],
          [0],
        ),
      ).to.be.revertedWithCustomError(freezeGuard, 'DAOFrozen()');
    });
  });

  it('A proposal can still be executed if a freeze proposal has been created, but threshold has not been met', async () => {
    // Create transaction to transfer tokens to the deployer
    const tokenTransferData = childVotesERC20.interface.encodeFunctionData('transfer', [
      deployer.address,
      10,
    ]);

    const proposalTransaction = {
      to: await childVotesERC20.getAddress(),
      value: 0n,
      data: tokenTransferData,
      operation: 0,
    };

    await azoriusModule.submitProposal(
      await linearERC20Voting.getAddress(),
      '0x',
      [proposalTransaction],
      '',
    );

    // Proposal is active
    expect(await azoriusModule.proposalState(0)).to.eq(0);

    // Both users vote in support of proposal
    await linearERC20Voting.connect(childTokenHolder1).vote(0, 1);
    await linearERC20Voting.connect(childTokenHolder2).vote(0, 1);

    // Increase time so that voting period has ended
    await time.advanceBlocks(60);

    // Proposal is timelocked
    expect(await azoriusModule.proposalState(0)).to.eq(1);

    expect(await freezeVoting.isFrozen()).to.eq(false);

    // One voter casts freeze vote
    await freezeVoting.connect(parentTokenHolder1).castFreezeVote();

    expect(await freezeVoting.isFrozen()).to.eq(false);

    // Increase time so that timelock period has ended
    await time.advanceBlocks(60);

    // Proposal is ready to execute
    expect(await azoriusModule.proposalState(0)).to.eq(2);

    expect(await childVotesERC20.balanceOf(await childGnosisSafe.getAddress())).to.eq(100);
    expect(await childVotesERC20.balanceOf(deployer.address)).to.eq(0);

    // Execute the transaction
    await azoriusModule.executeProposal(
      0,
      [await childVotesERC20.getAddress()],
      [0],
      [tokenTransferData],
      [0],
    );

    // Proposal is executed
    expect(await azoriusModule.proposalState(0)).to.eq(3);

    expect(await childVotesERC20.balanceOf(await childGnosisSafe.getAddress())).to.eq(90);
    expect(await childVotesERC20.balanceOf(deployer.address)).to.eq(10);
  });

  it('A frozen DAO is automatically unfrozen after the freeze duration is over', async () => {
    // Create transaction to transfer tokens to the deployer
    const tokenTransferData1 = childVotesERC20.interface.encodeFunctionData('transfer', [
      deployer.address,
      10,
    ]);

    const tokenTransferData2 = childVotesERC20.interface.encodeFunctionData('transfer', [
      deployer.address,
      5,
    ]);

    const proposalTransaction1 = {
      to: await childVotesERC20.getAddress(),
      value: 0n,
      data: tokenTransferData1,
      operation: 0,
    };

    const proposalTransaction2 = {
      to: await childVotesERC20.getAddress(),
      value: 0n,
      data: tokenTransferData2,
      operation: 0,
    };

    await azoriusModule.submitProposal(
      await linearERC20Voting.getAddress(),
      '0x',
      [proposalTransaction1],
      '',
    );
    await azoriusModule.submitProposal(
      await linearERC20Voting.getAddress(),
      '0x',
      [proposalTransaction2],
      '',
    );

    // Proposal is active
    expect(await azoriusModule.proposalState(0)).to.eq(0);
    expect(await azoriusModule.proposalState(1)).to.eq(0);

    // Both users vote in support of proposals
    await linearERC20Voting.connect(childTokenHolder1).vote(0, 1);
    await linearERC20Voting.connect(childTokenHolder2).vote(0, 1);

    await linearERC20Voting.connect(childTokenHolder1).vote(1, 1);
    await linearERC20Voting.connect(childTokenHolder2).vote(1, 1);

    // Increase time so that voting period has ended
    await time.advanceBlocks(60);

    // Proposal is timelocked
    expect(await azoriusModule.proposalState(0)).to.eq(1);
    expect(await azoriusModule.proposalState(1)).to.eq(1);

    expect(await freezeVoting.isFrozen()).to.eq(false);

    // Voters both cast freeze votes
    await freezeVoting.connect(parentTokenHolder1).castFreezeVote();
    await freezeVoting.connect(parentTokenHolder2).castFreezeVote();

    expect(await freezeVoting.isFrozen()).to.eq(true);

    // Increase time so that timelock period has ended
    await time.advanceBlocks(60);

    // Proposal is ready to execute
    expect(await azoriusModule.proposalState(0)).to.eq(2);
    expect(await azoriusModule.proposalState(1)).to.eq(2);

    // This proposal should fail due to freeze
    await expect(
      azoriusModule.executeProposal(
        0,
        [await childVotesERC20.getAddress()],
        [0],
        [tokenTransferData1],
        [0],
      ),
    ).to.be.revertedWithCustomError(freezeGuard, 'DAOFrozen()');

    // This proposal should fail due to freeze
    await expect(
      azoriusModule.executeProposal(
        1,
        [await childVotesERC20.getAddress()],
        [0],
        [tokenTransferData2],
        [0],
      ),
    ).to.be.revertedWithCustomError(freezeGuard, 'DAOFrozen()');

    // Increase time so that freeze has ended
    await time.advanceBlocks(100);

    const tokenTransferData3 = childVotesERC20.interface.encodeFunctionData('transfer', [
      deployer.address,
      4,
    ]);

    const proposalTransaction3 = {
      to: await childVotesERC20.getAddress(),
      value: 0n,
      data: tokenTransferData3,
      operation: 0,
    };

    await azoriusModule.submitProposal(
      await linearERC20Voting.getAddress(),
      '0x',
      [proposalTransaction3],
      '',
    );

    expect(await azoriusModule.proposalState(2)).to.eq(0);

    await linearERC20Voting.connect(childTokenHolder1).vote(2, 1);
    await linearERC20Voting.connect(childTokenHolder2).vote(2, 1);

    // Increase time so that voting period has ended
    await time.advanceBlocks(60);

    // Proposal is timelocked
    expect(await azoriusModule.proposalState(2)).to.eq(1);

    // Increase time so that timelock period has ended
    await time.advanceBlocks(60);

    // Proposal is ready to execute
    expect(await azoriusModule.proposalState(2)).to.eq(2);

    expect(await childVotesERC20.balanceOf(await childGnosisSafe.getAddress())).to.eq(100);
    expect(await childVotesERC20.balanceOf(deployer.address)).to.eq(0);

    // Execute the transaction
    await azoriusModule.executeProposal(
      2,
      [await childVotesERC20.getAddress()],
      [0],
      [tokenTransferData3],
      [0],
    );

    // Proposal is executed
    expect(await azoriusModule.proposalState(2)).to.eq(3);

    expect(await childVotesERC20.balanceOf(await childGnosisSafe.getAddress())).to.eq(96);
    expect(await childVotesERC20.balanceOf(deployer.address)).to.eq(4);
  });

  it("A frozen DAO can be unfrozen by its owner, and continue to execute TX's", async () => {
    // Create transaction to transfer tokens to the deployer
    const tokenTransferData1 = childVotesERC20.interface.encodeFunctionData('transfer', [
      deployer.address,
      10,
    ]);

    const tokenTransferData2 = childVotesERC20.interface.encodeFunctionData('transfer', [
      deployer.address,
      5,
    ]);

    const tokenTransferData3 = childVotesERC20.interface.encodeFunctionData('transfer', [
      deployer.address,
      4,
    ]);

    const proposalTransaction1 = {
      to: await childVotesERC20.getAddress(),
      value: 0n,
      data: tokenTransferData1,
      operation: 0,
    };

    const proposalTransaction2 = {
      to: await childVotesERC20.getAddress(),
      value: 0n,
      data: tokenTransferData2,
      operation: 0,
    };

    const proposalTransaction3 = {
      to: await childVotesERC20.getAddress(),
      value: 0n,
      data: tokenTransferData3,
      operation: 0,
    };

    await azoriusModule.submitProposal(
      await linearERC20Voting.getAddress(),
      '0x',
      [proposalTransaction1],
      '',
    );

    await azoriusModule.submitProposal(
      await linearERC20Voting.getAddress(),
      '0x',
      [proposalTransaction2],
      '',
    );

    await azoriusModule.submitProposal(
      await linearERC20Voting.getAddress(),
      '0x',
      [proposalTransaction3],
      '',
    );

    // Proposal is active
    expect(await azoriusModule.proposalState(0)).to.eq(0);
    expect(await azoriusModule.proposalState(1)).to.eq(0);
    expect(await azoriusModule.proposalState(2)).to.eq(0);

    // Both users vote in support of proposals
    await linearERC20Voting.connect(childTokenHolder1).vote(0, 1);
    await linearERC20Voting.connect(childTokenHolder2).vote(0, 1);

    await linearERC20Voting.connect(childTokenHolder1).vote(1, 1);
    await linearERC20Voting.connect(childTokenHolder2).vote(1, 1);

    await linearERC20Voting.connect(childTokenHolder1).vote(2, 1);
    await linearERC20Voting.connect(childTokenHolder2).vote(2, 1);

    // Increase time so that voting period has ended
    await time.advanceBlocks(60);

    // Proposal is timelocked
    expect(await azoriusModule.proposalState(0)).to.eq(1);
    expect(await azoriusModule.proposalState(1)).to.eq(1);
    expect(await azoriusModule.proposalState(2)).to.eq(1);

    expect(await freezeVoting.isFrozen()).to.eq(false);

    // Voters both cast freeze votes
    await freezeVoting.connect(parentTokenHolder1).castFreezeVote();

    await freezeVoting.connect(parentTokenHolder2).castFreezeVote();

    expect(await freezeVoting.isFrozen()).to.eq(true);

    // Increase time so that timelock period has ended
    await time.advanceBlocks(60);

    // Proposal is executable
    expect(await azoriusModule.proposalState(0)).to.eq(2);
    expect(await azoriusModule.proposalState(1)).to.eq(2);
    expect(await azoriusModule.proposalState(2)).to.eq(2);

    // This proposal should fail due to freeze
    await expect(
      azoriusModule.executeProposal(
        0,
        [await childVotesERC20.getAddress()],
        [0],
        [tokenTransferData1],
        [0],
      ),
    ).to.be.revertedWithCustomError(freezeGuard, 'DAOFrozen()');

    // This proposal should fail due to freeze
    await expect(
      azoriusModule.executeProposal(
        1,
        [await childVotesERC20.getAddress()],
        [0],
        [tokenTransferData2],
        [0],
      ),
    ).to.be.revertedWithCustomError(freezeGuard, 'DAOFrozen()');

    // This proposal should fail due to freeze
    await expect(
      azoriusModule.executeProposal(
        2,
        [await childVotesERC20.getAddress()],
        [0],
        [tokenTransferData3],
        [0],
      ),
    ).to.be.revertedWithCustomError(freezeGuard, 'DAOFrozen()');

    // Parent DAO unfreezes the child
    await freezeVoting.connect(mockParentDAO).unfreeze();

    // Child DAO is now unfrozen
    expect(await freezeVoting.isFrozen()).to.eq(false);

    expect(await childVotesERC20.balanceOf(await childGnosisSafe.getAddress())).to.eq(100);
    expect(await childVotesERC20.balanceOf(deployer.address)).to.eq(0);

    // Execute the transaction
    await azoriusModule.executeProposal(
      0,
      [await childVotesERC20.getAddress()],
      [0],
      [tokenTransferData1],
      [0],
    );

    expect(await childVotesERC20.balanceOf(await childGnosisSafe.getAddress())).to.eq(90);
    expect(await childVotesERC20.balanceOf(deployer.address)).to.eq(10);
  });

  it('Freeze state values are updated correctly throughout the freeze process', async () => {
    // freeze votes threshold => 150
    // freeze proposal duration in blocks => 10
    // freeze duration in blocks => 100

    // One voter casts freeze vote
    await freezeVoting.connect(parentTokenHolder1).castFreezeVote();

    const firstFreezeProposalCreatedBlock = (await hre.ethers.provider.getBlock('latest'))!.number;
    expect(await freezeVoting.freezeProposalCreatedBlock()).to.eq(firstFreezeProposalCreatedBlock);

    expect(await freezeVoting.freezeProposalVoteCount()).to.eq(100);

    expect(await freezeVoting.isFrozen()).to.eq(false);

    expect(
      await freezeVoting.userHasFreezeVoted(
        parentTokenHolder1.address,
        firstFreezeProposalCreatedBlock,
      ),
    ).to.eq(true);
    expect(
      await freezeVoting.userHasFreezeVoted(
        parentTokenHolder2.address,
        firstFreezeProposalCreatedBlock,
      ),
    ).to.eq(false);

    // Increase time so freeze proposal has ended
    await time.advanceBlocks(10);

    // One voter casts freeze vote, this should create a new freeze proposal
    await freezeVoting.connect(parentTokenHolder1).castFreezeVote();

    const secondFreezeProposalCreatedBlock = (await hre.ethers.provider.getBlock('latest'))!.number;

    expect(await freezeVoting.freezeProposalCreatedBlock()).to.eq(secondFreezeProposalCreatedBlock);

    expect(await freezeVoting.freezeProposalVoteCount()).to.eq(100);

    expect(await freezeVoting.isFrozen()).to.eq(false);

    expect(
      await freezeVoting.userHasFreezeVoted(
        parentTokenHolder1.address,
        secondFreezeProposalCreatedBlock,
      ),
    ).to.eq(true);
    expect(
      await freezeVoting.userHasFreezeVoted(
        parentTokenHolder2.address,
        secondFreezeProposalCreatedBlock,
      ),
    ).to.eq(false);

    // First voter cannot vote again
    await expect(
      freezeVoting.connect(parentTokenHolder1).castFreezeVote(),
    ).to.be.revertedWithCustomError(freezeVoting, 'AlreadyVoted');

    // Second voter casts freeze vote, should update state of current freeze proposal
    await freezeVoting.connect(parentTokenHolder2).castFreezeVote();

    expect(await freezeVoting.freezeProposalCreatedBlock()).to.eq(secondFreezeProposalCreatedBlock);

    expect(await freezeVoting.freezeProposalVoteCount()).to.eq(200);

    expect(await freezeVoting.isFrozen()).to.eq(true);

    expect(
      await freezeVoting.userHasFreezeVoted(
        parentTokenHolder1.address,
        secondFreezeProposalCreatedBlock,
      ),
    ).to.eq(true);
    expect(
      await freezeVoting.userHasFreezeVoted(
        parentTokenHolder2.address,
        secondFreezeProposalCreatedBlock,
      ),
    ).to.eq(true);

    // Move time forward, freeze should still be active
    await time.advanceBlocks(90);

    expect(await freezeVoting.isFrozen()).to.eq(true);

    // Move time forward, freeze should end
    await time.advanceBlocks(10);

    expect(await freezeVoting.freezeProposalCreatedBlock()).to.eq(secondFreezeProposalCreatedBlock);

    expect(await freezeVoting.freezeProposalVoteCount()).to.eq(200);

    expect(await freezeVoting.isFrozen()).to.eq(false);
  });

  it('A user with no freeze votes cannot cast freeze votes', async () => {
    // User has no freeze votes
    await expect(
      freezeVoting.connect(childTokenHolder1).castFreezeVote(),
    ).to.be.revertedWithCustomError(freezeVoting, 'NoVotes()');

    // Freeze proposal is created
    await freezeVoting.connect(parentTokenHolder1).castFreezeVote();

    // User has no freeze votes
    await expect(
      freezeVoting.connect(childTokenHolder1).castFreezeVote(),
    ).to.be.revertedWithCustomError(freezeVoting, 'NoVotes()');
  });

  describe('Version', function () {
    it('Azorius module should have a version', async function () {
      const version = await azoriusModule.getVersion();
      void expect(version).to.equal(1);
    });

    it('Linear ERC20 voting should have a version', async function () {
      const version = await linearERC20Voting.getVersion();
      void expect(version).to.equal(1);
    });

    it('Freeze voting should have a version', async function () {
      const version = await freezeVoting.getVersion();
      void expect(version).to.equal(1);
    });

    it('Freeze guard should have a version', async function () {
      const version = await freezeGuard.getVersion();
      void expect(version).to.equal(1);
    });

    it('Parent votes ERC20 should have a version', async function () {
      const version = await parentVotesERC20.getVersion();
      void expect(version).to.equal(1);
    });

    it('Child votes ERC20 should have a version', async function () {
      const version = await childVotesERC20.getVersion();
      void expect(version).to.equal(1);
    });
  });
});
