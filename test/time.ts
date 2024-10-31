import hre from 'hardhat';

const advanceBlock = async () => {
  await hre.ethers.provider.send('evm_mine', []);
};

const advanceBlocks = async (blockCount: number) => {
  for (let i = 0; i < blockCount; i++) {
    await advanceBlock();
  }
};

export const setTime = async (time: number) => {
  await hre.ethers.provider.send('evm_setNextBlockTimestamp', [time]);
  await hre.ethers.provider.send('evm_mine', []);
};

export const currentBlockTimestamp = async () => {
  return (await hre.ethers.provider.getBlock(await hre.ethers.provider.getBlockNumber()))!
    .timestamp;
};

const defaultExport = {
  advanceBlocks,
  advanceBlock,
};

export default defaultExport;
