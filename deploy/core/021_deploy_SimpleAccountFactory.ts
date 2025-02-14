import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { deployNonUpgradeable } from '../helpers/deployNonUpgradeable';

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  await deployNonUpgradeable(hre, 'SimpleAccountFactory', [
    '0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789',
  ]);
};

export default func;
