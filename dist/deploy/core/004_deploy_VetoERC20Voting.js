"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const deployNonUpgradeable_1 = require("../helpers/deployNonUpgradeable");
const func = async (hre) => {
    await (0, deployNonUpgradeable_1.deployNonUpgradeable)(hre, "VetoERC20Voting", []);
};
exports.default = func;
