import { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers';
import { expect } from 'chai';
import hre from 'hardhat';
import {
  DecentAutonomousAdmin,
  DecentAutonomousAdmin__factory,
  MockHats,
  MockHats__factory,
  MockHatsElectionsEligibility,
  MockHatsElectionsEligibility__factory,
} from '../typechain-types';
import { topHatIdToHatId } from './helpers';

describe('DecentAutonomousAdminHat', function () {
  // Signer accounts
  let deployer: SignerWithAddress;
  let currentWearer: SignerWithAddress;
  let randomUser: SignerWithAddress;
  let nominatedWearer: SignerWithAddress;

  // Contract instances
  let hatsProtocol: MockHats;
  let hatsElectionModule: MockHatsElectionsEligibility;
  let decentAutonomousAdminInstance: DecentAutonomousAdmin;

  // Variables
  let userHatId: bigint;

  beforeEach(async function () {
    // Get signers
    [deployer, currentWearer, nominatedWearer, randomUser] = await hre.ethers.getSigners();

    // Deploy MockHatsAutoAdmin (Mock Hats Protocol)
    hatsProtocol = await new MockHats__factory(deployer).deploy();

    // Deploy MockHatsElectionEligibility (Eligibility Module)
    hatsElectionModule = await new MockHatsElectionsEligibility__factory(deployer).deploy();

    const topHatId = topHatIdToHatId((await hatsProtocol.lastTopHatId()) + 1n);
    await hatsProtocol.mintTopHat(deployer.address, 'Details', 'imageURI');

    const adminHatId = await hatsProtocol.getNextId(topHatId);

    // Create Admin Hat
    await hatsProtocol.createHat(
      topHatId, // top hat id
      'Details', // Hat details
      100, // Max supply
      '0x0000000000000000000000000000000000004a75', // Eligibility module (none)
      '0x0000000000000000000000000000000000004a75', // Toggle module (none)
      true, // Is mutable
      'imageURI', // Image URI
    );

    // Deploy DecentAutonomousAdminHat contract with the admin hat ID
    decentAutonomousAdminInstance = await new DecentAutonomousAdmin__factory(deployer).deploy();
    const adminHatAddress = await decentAutonomousAdminInstance.getAddress();
    // Mint the admin hat to adminHatWearer
    await hatsProtocol.mintHat(adminHatId, adminHatAddress);

    userHatId = await hatsProtocol.getNextId(adminHatId);

    // Create User Hat under the admin hat
    await hatsProtocol.createHat(
      adminHatId, // Admin hat id
      'Details', // Hat details
      100, // Max supply
      await hatsElectionModule.getAddress(), // Eligibility module (election module)
      '0x0000000000000000000000000000000000004a75', // Toggle module (none)
      false, // Is mutable
      'imageURI', // Image URI
    );

    // Mint the user hat to currentWearer
    await hatsProtocol.mintHat(userHatId, await currentWearer.getAddress());
  });

  describe('triggerStartNextTerm', function () {
    it('should correctly validate current wearer and transfer', async function () {
      const args = {
        currentWearer: await currentWearer.getAddress(),
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
