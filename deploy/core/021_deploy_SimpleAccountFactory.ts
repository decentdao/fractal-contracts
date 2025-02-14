import { getNamedAccounts } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

const deploySimpleAccountFactory: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await getNamedAccounts();

  const entrypointAddress = '0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789';

  await hre.deployments.deploy('SimpleAccountFactory', {
    from: deployer,
    args: [entrypointAddress],
    log: true,
    gasLimit: 6e6,
    deterministicDeployment: true,
  });
};

export default deploySimpleAccountFactory;
