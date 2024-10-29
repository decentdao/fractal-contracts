import { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers';
import { expect } from 'chai';
import hre from 'hardhat';
import {
  DecentAutonomousAdmin,
  DecentAutonomousAdmin__factory,
  MockHats,
  MockHats__factory,
  MockHatsElectionEligibility,
  MockHatsElectionEligibility__factory,
} from '../typechain-types';

describe('DecentAutonomousAdminHat', function () {
  // Signer accounts
  let deployer: SignerWithAddress;
  let currentWearer: SignerWithAddress;
  let randomUser: SignerWithAddress;
  let nominatedWearer: SignerWithAddress;

  // Contract instances
  let hatsProtocol: MockHats;
  let hatsElectionModule: MockHatsElectionEligibility;
  let decentAutonomousAdminInstance: DecentAutonomousAdmin;

  // Variables
  let userHatId: bigint;

  beforeEach(async function () {
    // Get signers
    [deployer, currentWearer, nominatedWearer, randomUser] = await hre.ethers.getSigners();

    // Deploy MockHatsAutoAdmin (Mock Hats Protocol)
    hatsProtocol = await new MockHats__factory(deployer).deploy();

    // Deploy MockHatsElectionEligibility (Eligibility Module)
    hatsElectionModule = await new MockHatsElectionEligibility__factory(deployer).deploy();

    // Create Admin Hat
    const createAdminTx = await hatsProtocol.createHat(
      hre.ethers.ZeroAddress, // Admin address (self-administered), currently unused
      'Details', // Hat details
      100, // Max supply
      hre.ethers.ZeroAddress, // Eligibility module (none)
      hre.ethers.ZeroAddress, // Toggle module (none)
      true, // Is mutable
      'imageURI', // Image URI
    );
    const createAdminTxReceipt = await createAdminTx.wait();
    const adminHatId = createAdminTxReceipt?.toJSON().logs[0].args[0];

    // Deploy DecentAutonomousAdminHat contract with the admin hat ID
    decentAutonomousAdminInstance = await new DecentAutonomousAdmin__factory(deployer).deploy();
    const adminHatAddress = await decentAutonomousAdminInstance.getAddress();
    // Mint the admin hat to adminHatWearer
    await hatsProtocol.mintHat(adminHatId, adminHatAddress);

    // Create User Hat under the admin hat
    const createUserTx = await hatsProtocol.createHat(
      hre.ethers.ZeroAddress, // Admin address (decentAutonomousAdminInstance contract), currently unused
      'Details', // Hat details
      100, // Max supply
      await hatsElectionModule.getAddress(), // Eligibility module (election module)
      hre.ethers.ZeroAddress, // Toggle module (none)
      false, // Is mutable
      'imageURI', // Image URI
    );

    const createUserTxReceipt = await createUserTx.wait();
    userHatId = createUserTxReceipt?.toJSON().logs[0].args[0];

    // Mint the user hat to currentWearer
    await hatsProtocol.mintHat(userHatId, await currentWearer.getAddress());
  });

  describe('triggerStartNextTerm', function () {
    it('should correctly validate current wearer and transfer', async function () {
      const args = {
        currentWearer: currentWearer.address,
        hatsProtocol: await hatsProtocol.getAddress(),
        hatId: userHatId,
        nominatedWearer: nominatedWearer.address,
      };

      // Call triggerStartNextTerm on the decentAutonomousAdminInstance contract
      await decentAutonomousAdminInstance.triggerStartNextTerm(args);

      // Verify the hat is now worn by the nominated wearer
      expect((await hatsProtocol.isWearerOfHat(nominatedWearer.address, userHatId)) === true);

      expect((await hatsProtocol.isWearerOfHat(currentWearer.address, userHatId)) === false);
    });
    it('should correctly invalidate random address as current wearer', async function () {
      const args = {
        currentWearer: randomUser.address,
        hatsProtocol: await hatsProtocol.getAddress(),
        hatId: userHatId,
        nominatedWearer: nominatedWearer.address,
        sablierStreamInfo: [], // No Sablier stream info for this test
      };

      // revert if not the current wearer
      await expect(
        decentAutonomousAdminInstance.connect(randomUser).triggerStartNextTerm(args),
      ).to.be.revertedWithCustomError(decentAutonomousAdminInstance, 'NotCurrentWearer');
    });
  });
});
