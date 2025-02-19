import { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { KeyValuePairs, KeyValuePairs__factory } from '../../typechain-types';

describe('KeyValuePairs', function () {
  let keyValuePairs: KeyValuePairs;
  let deployer: SignerWithAddress;
  let user: SignerWithAddress;

  beforeEach(async function () {
    [deployer, user] = await ethers.getSigners();
    keyValuePairs = await new KeyValuePairs__factory(deployer).deploy();
  });

  describe('updateValues', function () {
    it('should emit ValueUpdated events for each key-value pair', async function () {
      const keys = ['name', 'age', 'city'];
      const values = ['Alice', '25', 'New York'];

      await expect(keyValuePairs.connect(user).updateValues(keys, values))
        .to.emit(keyValuePairs, 'ValueUpdated')
        .withArgs(user.address, 'name', 'Alice')
        .to.emit(keyValuePairs, 'ValueUpdated')
        .withArgs(user.address, 'age', '25')
        .to.emit(keyValuePairs, 'ValueUpdated')
        .withArgs(user.address, 'city', 'New York');
    });

    it('should work with a single key-value pair', async function () {
      const keys = ['single'];
      const values = ['value'];

      await expect(keyValuePairs.connect(user).updateValues(keys, values))
        .to.emit(keyValuePairs, 'ValueUpdated')
        .withArgs(user.address, 'single', 'value');
    });

    it('should work with empty arrays', async function () {
      const keys: string[] = [];
      const values: string[] = [];

      await expect(keyValuePairs.connect(user).updateValues(keys, values)).to.not.be.reverted;
    });

    it('should revert if keys and values arrays have different lengths', async function () {
      const keys = ['key1', 'key2'];
      const values = ['value1'];

      await expect(
        keyValuePairs.connect(user).updateValues(keys, values),
      ).to.be.revertedWithCustomError(keyValuePairs, 'IncorrectValueCount');

      const moreValues = ['value1', 'value2', 'value3'];
      await expect(
        keyValuePairs.connect(user).updateValues(keys, moreValues),
      ).to.be.revertedWithCustomError(keyValuePairs, 'IncorrectValueCount');
    });
  });
});
