import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('SimpleAccountFactory', {
    from: deployer,
    args: ['0x0000000071727de22e5e9d8baf0edac6f37da032'],
    log: true,
    gasLimit: 6e6,
    deterministicDeployment: true,
  });
};

export default func;
func.tags = ['SimpleAccountFactory'];
