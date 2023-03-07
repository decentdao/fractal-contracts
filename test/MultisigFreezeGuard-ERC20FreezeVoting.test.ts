import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { BigNumber, Contract } from "ethers";
import { ethers, network } from "hardhat";
import time from "./time";
import {
  VotesToken,
  VotesToken__factory,
  ERC20FreezeVoting,
  ERC20FreezeVoting__factory,
  MultisigFreezeGuard,
  MultisigFreezeGuard__factory,
} from "../typechain-types";
import {
  buildSignatureBytes,
  buildSafeTransaction,
  safeSignTypedData,
  ifaceSafe,
  abi,
  predictGnosisSafeAddress,
  abiSafe,
} from "./helpers";

describe("Child Multisig DAO with Azorius Parent", () => {
  // Factories
  let gnosisFactory: Contract;

  // Deployed contracts
  let gnosisSafe: Contract;
  let freezeGuard: MultisigFreezeGuard;
  let freezeVoting: ERC20FreezeVoting;
  let votesToken: VotesToken;

  // Wallets
  let deployer: SignerWithAddress;
  let owner1: SignerWithAddress;
  let owner2: SignerWithAddress;
  let owner3: SignerWithAddress;
  let tokenVetoer1: SignerWithAddress;
  let tokenVetoer2: SignerWithAddress;
  let freezeGuardOwner: SignerWithAddress;

  // Gnosis
  let createGnosisSetupCalldata: string;

  const gnosisFactoryAddress = "0xa6B71E26C5e0845f74c812102Ca7114b6a896AB2";
  const gnosisSingletonAddress = "0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552";
  const threshold = 2;
  const saltNum = BigNumber.from(
    "0x856d90216588f9ffc124d1480a440e1c012c7a816952bc968d737bae5d4e139c"
  );

  beforeEach(async () => {
    // Fork Goerli to use contracts deployed on Goerli
    await network.provider.request({
      method: "hardhat_reset",
      params: [
        {
          forking: {
            jsonRpcUrl: process.env.GOERLI_PROVIDER
              ? process.env.GOERLI_PROVIDER
              : "",
            blockNumber: 7387621,
          },
        },
      ],
    });

    [
      deployer,
      owner1,
      owner2,
      owner3,
      tokenVetoer1,
      tokenVetoer2,
      freezeGuardOwner,
    ] = await ethers.getSigners();

    // Get deployed Gnosis Safe
    gnosisFactory = new ethers.Contract(gnosisFactoryAddress, abi, deployer);

    createGnosisSetupCalldata = ifaceSafe.encodeFunctionData("setup", [
      [owner1.address, owner2.address, owner3.address],
      threshold,
      ethers.constants.AddressZero,
      ethers.constants.HashZero,
      ethers.constants.AddressZero,
      ethers.constants.AddressZero,
      0,
      ethers.constants.AddressZero,
    ]);

    const predictedGnosisSafeAddress = await predictGnosisSafeAddress(
      gnosisFactory.address,
      createGnosisSetupCalldata,
      saltNum,
      gnosisSingletonAddress,
      gnosisFactory
    );

    // Deploy Gnosis Safe
    await gnosisFactory.createProxyWithNonce(
      gnosisSingletonAddress,
      createGnosisSetupCalldata,
      saltNum
    );

    // Get Gnosis Safe contract
    gnosisSafe = new ethers.Contract(
      predictedGnosisSafeAddress,
      abiSafe,
      deployer
    );

    // Deploy token, allocate supply to two token vetoers and Gnosis Safe
    votesToken = await new VotesToken__factory(deployer).deploy();

    const abiCoder = new ethers.utils.AbiCoder(); // encode data
    const votesTokenSetupData = abiCoder.encode(
      ["string", "string", "address[]", "uint256[]"],
      [
        "DCNT",
        "DCNT",
        [tokenVetoer1.address, tokenVetoer2.address, gnosisSafe.address],
        [500, 600, 1000],
      ]
    );

    await votesToken.setUp(votesTokenSetupData);

    // Vetoers delegate their votes to themselves
    await votesToken.connect(tokenVetoer1).delegate(tokenVetoer1.address);
    await votesToken.connect(tokenVetoer2).delegate(tokenVetoer2.address);

    // Deploy ERC20FreezeVoting contract
    freezeVoting = await new ERC20FreezeVoting__factory(deployer).deploy();

    // Deploy MultisigFreezeGuard contract with a 60 second timelock period, and a 60 second execution period
    const freezeGuardSetupData = abiCoder.encode(
      ["uint256", "uint256", "address", "address", "address"],
      [
        60, // Timelock period
        60, // Execution period
        freezeGuardOwner.address,
        freezeVoting.address,
        gnosisSafe.address,
      ]
    );
    freezeGuard = await new MultisigFreezeGuard__factory(deployer).deploy();
    await freezeGuard.setUp(freezeGuardSetupData);

    // Initialize FreezeVoting contract
    const freezeVotingSetupData = abiCoder.encode(
      ["address", "uint256", "uint256", "uint256", "address", "address"],
      [
        freezeGuardOwner.address,
        1090, // freeze votes threshold
        10, // freeze proposal period
        200, // freeze period
        votesToken.address,
        freezeGuard.address,
      ]
    );
    await freezeVoting.setUp(freezeVotingSetupData);

    // Create transaction to set the guard address
    const setGuardData = gnosisSafe.interface.encodeFunctionData("setGuard", [
      freezeGuard.address,
    ]);

    const tx = buildSafeTransaction({
      to: gnosisSafe.address,
      data: setGuardData,
      safeTxGas: 1000000,
      nonce: await gnosisSafe.nonce(),
    });
    const sigs = [
      await safeSignTypedData(owner1, gnosisSafe, tx),
      await safeSignTypedData(owner2, gnosisSafe, tx),
    ];
    const signatureBytes = buildSignatureBytes(sigs);

    // Execute transaction that adds the veto guard to the Safe
    await expect(
      gnosisSafe.execTransaction(
        tx.to,
        tx.value,
        tx.data,
        tx.operation,
        tx.safeTxGas,
        tx.baseGas,
        tx.gasPrice,
        tx.gasToken,
        tx.refundReceiver,
        signatureBytes
      )
    ).to.emit(gnosisSafe, "ExecutionSuccess");

    // Gnosis Safe received the 1,000 tokens
    expect(await votesToken.balanceOf(gnosisSafe.address)).to.eq(1000);
  });

  describe("FreezeGuard Functionality", () => {
    it("Freeze parameters correctly setup", async () => {
      // Frozen Params init correctly
      expect(await freezeVoting.freezeVotesThreshold()).to.eq(1090);
      expect(await freezeVoting.freezeProposalPeriod()).to.eq(10);
      expect(await freezeVoting.freezePeriod()).to.eq(200);
      expect(await freezeVoting.owner()).to.eq(freezeGuardOwner.address);
    });

    it("Updates state properly due to freeze actions", async () => {
      expect(await freezeVoting.freezeProposalVoteCount()).to.eq(0);
      expect(await freezeVoting.freezeProposalCreatedBlock()).to.eq(0);

      // Vetoer 1 casts 500 freeze votes
      await freezeVoting.connect(tokenVetoer1).castFreezeVote();
      expect(await freezeVoting.isFrozen()).to.eq(false);
      expect(await freezeVoting.freezeProposalVoteCount()).to.eq(500);
      const latestBlock = await ethers.provider.getBlock("latest");
      expect(await freezeVoting.freezeProposalCreatedBlock()).to.eq(
        latestBlock.number
      );

      await freezeVoting.connect(tokenVetoer2).castFreezeVote();
      expect(await freezeVoting.isFrozen()).to.eq(true);
    });

    it("A transaction can be timelocked and executed", async () => {
      // Create transaction to set the guard address
      const tokenTransferData = votesToken.interface.encodeFunctionData(
        "transfer",
        [deployer.address, 1000]
      );

      const tx = buildSafeTransaction({
        to: votesToken.address,
        data: tokenTransferData,
        safeTxGas: 1000000,
        nonce: await gnosisSafe.nonce(),
      });

      const sigs = [
        await safeSignTypedData(owner1, gnosisSafe, tx),
        await safeSignTypedData(owner2, gnosisSafe, tx),
      ];
      const signatureBytes = buildSignatureBytes(sigs);

      await freezeGuard.timelockTransaction(
        tx.to,
        tx.value,
        tx.data,
        tx.operation,
        tx.safeTxGas,
        tx.baseGas,
        tx.gasPrice,
        tx.gasToken,
        tx.refundReceiver,
        signatureBytes
      );

      // Move time forward to elapse timelock period
      await time.increase(time.duration.seconds(60));

      await gnosisSafe.execTransaction(
        tx.to,
        tx.value,
        tx.data,
        tx.operation,
        tx.safeTxGas,
        tx.baseGas,
        tx.gasPrice,
        tx.gasToken,
        tx.refundReceiver,
        signatureBytes
      );

      expect(await votesToken.balanceOf(gnosisSafe.address)).to.eq(0);
      expect(await votesToken.balanceOf(deployer.address)).to.eq(1000);
    });

    it("A transaction cannot be executed if it hasn't yet been timelocked", async () => {
      // Create transaction to set the guard address
      const tokenTransferData = votesToken.interface.encodeFunctionData(
        "transfer",
        [deployer.address, 1000]
      );

      const tx = buildSafeTransaction({
        to: votesToken.address,
        data: tokenTransferData,
        safeTxGas: 1000000,
        nonce: await gnosisSafe.nonce(),
      });

      const sigs = [
        await safeSignTypedData(owner1, gnosisSafe, tx),
        await safeSignTypedData(owner2, gnosisSafe, tx),
      ];
      const signatureBytes = buildSignatureBytes(sigs);

      await expect(
        gnosisSafe.execTransaction(
          tx.to,
          tx.value,
          tx.data,
          tx.operation,
          tx.safeTxGas,
          tx.baseGas,
          tx.gasPrice,
          tx.gasToken,
          tx.refundReceiver,
          signatureBytes
        )
      ).to.be.revertedWith("Transaction has not been timelocked yet");
    });

    it("A transaction cannot be timelocked if the signatures aren't valid", async () => {
      // Create transaction to set the guard address
      const tokenTransferData = votesToken.interface.encodeFunctionData(
        "transfer",
        [deployer.address, 1000]
      );

      const tx = buildSafeTransaction({
        to: votesToken.address,
        data: tokenTransferData,
        safeTxGas: 1000000,
        nonce: await gnosisSafe.nonce(),
      });

      // Only 1 signer signs, while the threshold is 2
      const sigs = [await safeSignTypedData(owner1, gnosisSafe, tx)];
      const signatureBytes = buildSignatureBytes(sigs);

      await expect(
        freezeGuard.timelockTransaction(
          tx.to,
          tx.value,
          tx.data,
          tx.operation,
          tx.safeTxGas,
          tx.baseGas,
          tx.gasPrice,
          tx.gasToken,
          tx.refundReceiver,
          signatureBytes
        )
      ).to.be.revertedWith("GS020");
    });

    it("A transaction cannot be executed if the timelock period has not ended yet", async () => {
      // Create transaction to set the guard address
      const tokenTransferData = votesToken.interface.encodeFunctionData(
        "transfer",
        [deployer.address, 1000]
      );

      const tx = buildSafeTransaction({
        to: votesToken.address,
        data: tokenTransferData,
        safeTxGas: 1000000,
        nonce: await gnosisSafe.nonce(),
      });

      const sigs = [
        await safeSignTypedData(owner1, gnosisSafe, tx),
        await safeSignTypedData(owner2, gnosisSafe, tx),
      ];
      const signatureBytes = buildSignatureBytes(sigs);

      await freezeGuard.timelockTransaction(
        tx.to,
        tx.value,
        tx.data,
        tx.operation,
        tx.safeTxGas,
        tx.baseGas,
        tx.gasPrice,
        tx.gasToken,
        tx.refundReceiver,
        signatureBytes
      );

      await expect(
        gnosisSafe.execTransaction(
          tx.to,
          tx.value,
          tx.data,
          tx.operation,
          tx.safeTxGas,
          tx.baseGas,
          tx.gasPrice,
          tx.gasToken,
          tx.refundReceiver,
          signatureBytes
        )
      ).to.be.revertedWith("Transaction timelock period has not completed yet");
    });

    it("A DAO may execute txs during a the freeze proposal period if the freeze threshold is not met", async () => {
      // Vetoer 1 casts 500 freeze votes
      await freezeVoting.connect(tokenVetoer1).castFreezeVote();

      // Check that the DAO has been frozen
      expect(await freezeVoting.isFrozen()).to.eq(false);

      // Create transaction to set the guard address
      const tokenTransferData1 = votesToken.interface.encodeFunctionData(
        "transfer",
        [deployer.address, 1000]
      );

      const tx1 = buildSafeTransaction({
        to: votesToken.address,
        data: tokenTransferData1,
        safeTxGas: 1000000,
        nonce: await gnosisSafe.nonce(),
      });

      const sigs1 = [
        await safeSignTypedData(owner1, gnosisSafe, tx1),
        await safeSignTypedData(owner2, gnosisSafe, tx1),
      ];
      const signatureBytes1 = buildSignatureBytes(sigs1);

      await freezeGuard.timelockTransaction(
        tx1.to,
        tx1.value,
        tx1.data,
        tx1.operation,
        tx1.safeTxGas,
        tx1.baseGas,
        tx1.gasPrice,
        tx1.gasToken,
        tx1.refundReceiver,
        signatureBytes1
      );

      // Move time forward to elapse timelock period
      await time.increase(time.duration.seconds(60));

      await expect(
        gnosisSafe.execTransaction(
          tx1.to,
          tx1.value,
          tx1.data,
          tx1.operation,
          tx1.safeTxGas,
          tx1.baseGas,
          tx1.gasPrice,
          tx1.gasToken,
          tx1.refundReceiver,
          signatureBytes1
        )
      ).to.emit(gnosisSafe, "ExecutionSuccess");
    });

    it("Casting a vote after the freeze voting period resets state", async () => {
      expect(await freezeVoting.freezeProposalVoteCount()).to.eq(0);
      expect(await freezeVoting.freezeProposalCreatedBlock()).to.eq(0);

      // Vetoer 1 casts 500 freeze votes
      await freezeVoting.connect(tokenVetoer1).castFreezeVote();
      expect(await freezeVoting.isFrozen()).to.eq(false);
      expect(await freezeVoting.freezeProposalVoteCount()).to.eq(500);
      let latestBlock = await ethers.provider.getBlock("latest");
      expect(await freezeVoting.freezeProposalCreatedBlock()).to.eq(
        latestBlock.number
      );

      // Move time forward to elapse freeze proposal period
      await time.increase(time.duration.seconds(10));

      await freezeVoting.connect(tokenVetoer1).castFreezeVote();
      expect(await freezeVoting.freezeProposalVoteCount()).to.eq(500);
      latestBlock = await ethers.provider.getBlock("latest");
      expect(await freezeVoting.freezeProposalCreatedBlock()).to.eq(
        latestBlock.number
      );
      expect(await freezeVoting.isFrozen()).to.eq(false);
    });

    it("A user cannot vote twice to freeze a dao during the same voting period", async () => {
      await freezeVoting.connect(tokenVetoer1).castFreezeVote();
      await expect(
        freezeVoting.connect(tokenVetoer1).castFreezeVote()
      ).to.be.revertedWith("User has already voted");
      expect(await freezeVoting.freezeProposalVoteCount()).to.eq(500);
    });

    it("An unfrozen DAO may not execute a previously passed transaction", async () => {
      // Vetoer 1 casts 500 freeze votes
      await freezeVoting.connect(tokenVetoer1).castFreezeVote();
      // Vetoer 2 casts 600 freeze votes
      await freezeVoting.connect(tokenVetoer2).castFreezeVote();

      // Check that the DAO has been frozen
      expect(await freezeVoting.isFrozen()).to.eq(true);

      // Create transaction to set the guard address
      const tokenTransferData1 = votesToken.interface.encodeFunctionData(
        "transfer",
        [deployer.address, 1000]
      );

      const tx1 = buildSafeTransaction({
        to: votesToken.address,
        data: tokenTransferData1,
        safeTxGas: 1000000,
        nonce: await gnosisSafe.nonce(),
      });

      const sigs1 = [
        await safeSignTypedData(owner1, gnosisSafe, tx1),
        await safeSignTypedData(owner2, gnosisSafe, tx1),
      ];
      const signatureBytes1 = buildSignatureBytes(sigs1);

      await freezeGuard.timelockTransaction(
        tx1.to,
        tx1.value,
        tx1.data,
        tx1.operation,
        tx1.safeTxGas,
        tx1.baseGas,
        tx1.gasPrice,
        tx1.gasToken,
        tx1.refundReceiver,
        signatureBytes1
      );

      // Move time forward to elapse timelock period
      await time.increase(time.duration.seconds(60));

      await expect(
        gnosisSafe.execTransaction(
          tx1.to,
          tx1.value,
          tx1.data,
          tx1.operation,
          tx1.safeTxGas,
          tx1.baseGas,
          tx1.gasPrice,
          tx1.gasToken,
          tx1.refundReceiver,
          signatureBytes1
        )
      ).to.be.revertedWith("DAO is frozen");

      // Move time forward to elapse freeze period
      await time.increase(time.duration.seconds(140));

      // Check that the DAO has been unFrozen
      expect(await freezeVoting.isFrozen()).to.eq(false);
      await expect(
        gnosisSafe.execTransaction(
          tx1.to,
          tx1.value,
          tx1.data,
          tx1.operation,
          tx1.safeTxGas,
          tx1.baseGas,
          tx1.gasPrice,
          tx1.gasToken,
          tx1.refundReceiver,
          signatureBytes1
        )
      ).to.be.revertedWith("Transaction execution period has ended");
    });

    it("Unfrozen DAOs may execute txs", async () => {
      // Vetoer 1 casts 500 freeze votes
      await freezeVoting.connect(tokenVetoer1).castFreezeVote();
      // Vetoer 2 casts 600 freeze votes
      await freezeVoting.connect(tokenVetoer2).castFreezeVote();

      // Check that the DAO has been frozen
      expect(await freezeVoting.isFrozen()).to.eq(true);
      await freezeVoting.connect(freezeGuardOwner).unfreeze();
      expect(await freezeVoting.isFrozen()).to.eq(false);

      // Create transaction to set the guard address
      const tokenTransferData1 = votesToken.interface.encodeFunctionData(
        "transfer",
        [deployer.address, 1000]
      );

      const tx1 = buildSafeTransaction({
        to: votesToken.address,
        data: tokenTransferData1,
        safeTxGas: 1000000,
        nonce: await gnosisSafe.nonce(),
      });

      const sigs1 = [
        await safeSignTypedData(owner1, gnosisSafe, tx1),
        await safeSignTypedData(owner2, gnosisSafe, tx1),
      ];
      const signatureBytes1 = buildSignatureBytes(sigs1);

      await freezeGuard.timelockTransaction(
        tx1.to,
        tx1.value,
        tx1.data,
        tx1.operation,
        tx1.safeTxGas,
        tx1.baseGas,
        tx1.gasPrice,
        tx1.gasToken,
        tx1.refundReceiver,
        signatureBytes1
      );

      // Move time forward to elapse timelock period
      await time.increase(time.duration.seconds(60));

      // Check that the DAO has been unFrozen
      await expect(
        gnosisSafe.execTransaction(
          tx1.to,
          tx1.value,
          tx1.data,
          tx1.operation,
          tx1.safeTxGas,
          tx1.baseGas,
          tx1.gasPrice,
          tx1.gasToken,
          tx1.refundReceiver,
          signatureBytes1
        )
      ).to.emit(gnosisSafe, "ExecutionSuccess");
    });

    it("You must have voting weight to cast a freeze vote", async () => {
      await expect(
        freezeVoting.connect(freezeGuardOwner).castFreezeVote()
      ).to.be.revertedWith("User has no votes");
      freezeVoting.connect(tokenVetoer1).castFreezeVote();
      await expect(
        freezeVoting.connect(freezeGuardOwner).castFreezeVote()
      ).to.be.revertedWith("User has no votes");
    });

    it("Only owner methods must be called by vetoGuard owner", async () => {
      await expect(
        freezeVoting.connect(tokenVetoer1).unfreeze()
      ).to.be.revertedWith("Ownable: caller is not the owner");
      await expect(
        freezeVoting.connect(tokenVetoer1).updateFreezeVotesThreshold(0)
      ).to.be.revertedWith("Ownable: caller is not the owner");
      await expect(
        freezeVoting.connect(tokenVetoer1).updateFreezeProposalPeriod(0)
      ).to.be.revertedWith("Ownable: caller is not the owner");
      await expect(
        freezeVoting.connect(tokenVetoer1).updateFreezePeriod(0)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });
});
