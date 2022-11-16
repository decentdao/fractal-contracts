"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.buildMultiSendSafeTx = exports.encodeMultiSend = exports.buildSafeTransaction = exports.executeContractCallWithSigners = exports.executeTxWithSigners = exports.buildContractCall = exports.populateExecuteTx = exports.executeTx = exports.logGas = exports.buildSignatureBytes = exports.safeSignMessage = exports.signHash = exports.safeSignTypedData = exports.safeApproveHash = exports.calculateSafeMessageHash = exports.calculateSafeTransactionHash = exports.preimageSafeTransactionHash = exports.calculateSafeDomainSeparator = exports.abiUsul = exports.abiFactory = exports.abiSafe = exports.multisendABI = exports.abi = exports.usuliface = exports.ifaceFactory = exports.ifaceMultiSend = exports.ifaceSafe = exports.iface = exports.EIP712_SAFE_MESSAGE_TYPE = exports.EIP712_SAFE_TX_TYPE = exports.EIP_DOMAIN = exports.calculateProxyAddress = exports.predictGnosisSafeCallbackAddress = exports.predictGnosisSafeAddress = void 0;
const ethers_1 = require("ethers");
const constants_1 = require("@ethersproject/constants");
const utils_1 = require("ethers/lib/utils");
const predictGnosisSafeAddress = async (factory, calldata, saltNum, singleton, gnosisFactory) => {
    return ethers_1.ethers.utils.getCreate2Address(factory, ethers_1.ethers.utils.solidityKeccak256(["bytes", "uint256"], [ethers_1.ethers.utils.solidityKeccak256(["bytes"], [calldata]), saltNum]), ethers_1.ethers.utils.solidityKeccak256(["bytes", "uint256"], [
        // eslint-disable-next-line camelcase
        await gnosisFactory.proxyCreationCode(),
        singleton,
    ]));
};
exports.predictGnosisSafeAddress = predictGnosisSafeAddress;
const predictGnosisSafeCallbackAddress = async (factory, calldata, saltNum, callback, singleton, gnosisFactory) => {
    return ethers_1.ethers.utils.getCreate2Address(factory, ethers_1.ethers.utils.solidityKeccak256(["bytes", "bytes"], [
        ethers_1.ethers.utils.solidityKeccak256(["bytes"], [calldata]),
        ethers_1.ethers.utils.solidityKeccak256(["uint256", "address"], [saltNum, callback]),
    ]), ethers_1.ethers.utils.solidityKeccak256(["bytes", "uint256"], [
        // eslint-disable-next-line camelcase
        await gnosisFactory.proxyCreationCode(),
        singleton,
    ]));
};
exports.predictGnosisSafeCallbackAddress = predictGnosisSafeCallbackAddress;
const calculateProxyAddress = (factory, masterCopy, initData, saltNonce) => {
    const masterCopyAddress = masterCopy.toLowerCase().replace(/^0x/, "");
    const byteCode = "0x602d8060093d393df3363d3d373d3d3d363d73" +
        masterCopyAddress +
        "5af43d82803e903d91602b57fd5bf3";
    const salt = ethers_1.ethers.utils.solidityKeccak256(["bytes32", "uint256"], [ethers_1.ethers.utils.solidityKeccak256(["bytes"], [initData]), saltNonce]);
    return ethers_1.ethers.utils.getCreate2Address(factory.address, salt, ethers_1.ethers.utils.keccak256(byteCode));
};
exports.calculateProxyAddress = calculateProxyAddress;
exports.EIP_DOMAIN = {
    EIP712Domain: [
        { type: "uint256", name: "chainId" },
        { type: "address", name: "verifyingContract" },
    ],
};
exports.EIP712_SAFE_TX_TYPE = {
    // "SafeTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 nonce)"
    SafeTx: [
        { type: "address", name: "to" },
        { type: "uint256", name: "value" },
        { type: "bytes", name: "data" },
        { type: "uint8", name: "operation" },
        { type: "uint256", name: "safeTxGas" },
        { type: "uint256", name: "baseGas" },
        { type: "uint256", name: "gasPrice" },
        { type: "address", name: "gasToken" },
        { type: "address", name: "refundReceiver" },
        { type: "uint256", name: "nonce" },
    ],
};
exports.EIP712_SAFE_MESSAGE_TYPE = {
    // "SafeMessage(bytes message)"
    SafeMessage: [{ type: "bytes", name: "message" }],
};
exports.iface = new utils_1.Interface([
    "function createProxyWithNonce(address _singleton, bytes memory initializer, uint256 saltNonce) returns (GnosisSafeProxy proxy)",
    "function createProxyWithCallback(address _singleton,bytes memory initializer,uint256 saltNonce,address callback) public returns (address proxy)",
]);
exports.ifaceSafe = new utils_1.Interface([
    "event RemovedOwner(address owner)",
    "function setup(address[] calldata _owners,uint256 _threshold,address to,bytes calldata data,address fallbackHandler,address paymentToken,uint256 payment,address payable paymentReceiver)",
    "function execTransaction(address to,uint256 value,bytes calldata data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address payable refundReceiver,bytes memory signatures) public payable returns (bool success)",
    "function setGuard(address guard) external",
    "function addOwnerWithThreshold(address owner, uint256 _threshold) external",
    "function swapOwner(address prevOwner,address oldOwner,address newOwner) external",
    "function changeThreshold(uint256 _threshold) external",
    "function removeOwner(address prevOwner,address owner,uint256 _threshold) external",
    "function isOwner(address owner) public view returns (bool)",
    "function enableModule(address module) public",
    "function nonce() public view returns (uint256)",
]);
exports.ifaceMultiSend = new utils_1.Interface([
    "function multiSend(bytes memory transactions) public payable",
]);
exports.ifaceFactory = new utils_1.Interface([
    "function deployModule(address masterCopy,bytes memory initializer,uint256 saltNonce) public returns (address proxy)",
    "event ModuleProxyCreation(address indexed proxy,address indexed masterCopy)",
]);
exports.usuliface = new utils_1.Interface([
    "function setUp(bytes memory initParams) public",
]);
exports.abi = [
    "event ProxyCreation(address proxy, address singleton)",
    "function createProxy(address singleton, bytes memory data) public returns (address proxy)",
    "function proxyRuntimeCode() public pure returns (bytes memory)",
    "function proxyCreationCode() public pure returns (bytes memory)",
    "function createProxyWithNonce(address _singleton,bytes memory initializer,uint256 saltNonce) returns (address proxy)",
    "function createProxyWithCallback(address _singleton,bytes memory initializer,uint256 saltNonce,address callback) public returns (address proxy)",
    "function calculateCreateProxyWithNonceAddress(address _singleton,bytes calldata initializer,uint256 saltNonce) external returns (address proxy)",
];
exports.multisendABI = [
    "function multiSend(bytes memory transactions) public payable",
];
exports.abiSafe = [
    "event ExecutionSuccess(bytes32 txHash, uint256 payment)",
    "event ChangedGuard(address guard)",
    "event RemovedOwner(address owner)",
    "event SafeSetup(address indexed initiator, address[] owners, uint256 threshold, address initializer, address fallbackHandler)",
    "event EnabledModule(address module)",
    "event ExecutionFromModuleSuccess(address indexed module)",
    "event ExecutionFromModuleFailure(address indexed module)",
    "function getOwners() public view returns (address[] memory)",
    "function nonce() public view returns (uint256)",
    "function isOwner(address owner) public view returns (bool)",
    "function getThreshold() public view returns (uint256)",
    "function setup(address[] calldata _owners,uint256 _threshold,address to,bytes calldata data,address fallbackHandler,address paymentToken,uint256 payment,address payable paymentReceiver)",
    "function execTransaction(address to,uint256 value,bytes calldata data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address payable refundReceiver,bytes memory signatures) public payable returns (bool success)",
    "function getTransactionHash(address to,uint256 value,bytes calldata data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 _nonce) public view returns (bytes32)",
    "function setGuard(address guard) external",
    "function enableModule(address module) public",
    "function removeOwner(address prevOwner,address owner,uint256 _threshold) external",
    "function isModuleEnabled(address module) public view returns (bool)",
];
exports.abiFactory = [
    "event ModuleProxyCreation(address indexed proxy,address indexed masterCopy)",
    "function deployModule(address masterCopy,bytes memory initializer,uint256 saltNonce) public returns (address proxy)",
];
exports.abiUsul = [
    "function owner() public view returns (address)",
    "function avatar() public view returns (address)",
    "function target() public view returns (address)",
];
const calculateSafeDomainSeparator = (safe, chainId) => {
    return ethers_1.utils._TypedDataEncoder.hashDomain({
        verifyingContract: safe.address,
        chainId,
    });
};
exports.calculateSafeDomainSeparator = calculateSafeDomainSeparator;
const preimageSafeTransactionHash = (safe, safeTx, chainId) => {
    return ethers_1.utils._TypedDataEncoder.encode({ verifyingContract: safe.address, chainId }, exports.EIP712_SAFE_TX_TYPE, safeTx);
};
exports.preimageSafeTransactionHash = preimageSafeTransactionHash;
const calculateSafeTransactionHash = (safe, safeTx, chainId) => {
    return ethers_1.utils._TypedDataEncoder.hash({ verifyingContract: safe.address, chainId }, exports.EIP712_SAFE_TX_TYPE, safeTx);
};
exports.calculateSafeTransactionHash = calculateSafeTransactionHash;
const calculateSafeMessageHash = (safe, message, chainId) => {
    return ethers_1.utils._TypedDataEncoder.hash({ verifyingContract: safe.address, chainId }, exports.EIP712_SAFE_MESSAGE_TYPE, { message });
};
exports.calculateSafeMessageHash = calculateSafeMessageHash;
const safeApproveHash = async (signer, safe, safeTx, skipOnChainApproval) => {
    if (!skipOnChainApproval) {
        if (!signer.provider)
            throw Error("Provider required for on-chain approval");
        const chainId = (await signer.provider.getNetwork()).chainId;
        const typedDataHash = ethers_1.utils.arrayify((0, exports.calculateSafeTransactionHash)(safe, safeTx, chainId));
        const signerSafe = safe.connect(signer);
        await signerSafe.approveHash(typedDataHash);
    }
    const signerAddress = await signer.getAddress();
    return {
        signer: signerAddress,
        data: "0x000000000000000000000000" +
            signerAddress.slice(2) +
            "0000000000000000000000000000000000000000000000000000000000000000" +
            "01",
    };
};
exports.safeApproveHash = safeApproveHash;
const safeSignTypedData = async (signer, safe, safeTx, chainId) => {
    if (!chainId && !signer.provider)
        throw Error("Provider required to retrieve chainId");
    const cid = chainId || (await signer.provider.getNetwork()).chainId;
    const signerAddress = await signer.getAddress();
    return {
        signer: signerAddress,
        data: await signer._signTypedData({ verifyingContract: safe.address, chainId: cid }, exports.EIP712_SAFE_TX_TYPE, safeTx),
    };
};
exports.safeSignTypedData = safeSignTypedData;
const signHash = async (signer, hash) => {
    const typedDataHash = ethers_1.utils.arrayify(hash);
    const signerAddress = await signer.getAddress();
    return {
        signer: signerAddress,
        data: (await signer.signMessage(typedDataHash))
            .replace(/1b$/, "1f")
            .replace(/1c$/, "20"),
    };
};
exports.signHash = signHash;
const safeSignMessage = async (signer, safe, safeTx, chainId) => {
    const cid = chainId || (await signer.provider.getNetwork()).chainId;
    return (0, exports.signHash)(signer, (0, exports.calculateSafeTransactionHash)(safe, safeTx, cid));
};
exports.safeSignMessage = safeSignMessage;
const buildSignatureBytes = (signatures) => {
    signatures.sort((left, right) => left.signer.toLowerCase().localeCompare(right.signer.toLowerCase()));
    let signatureBytes = "0x";
    for (const sig of signatures) {
        signatureBytes += sig.data.slice(2);
    }
    return signatureBytes;
};
exports.buildSignatureBytes = buildSignatureBytes;
const logGas = async (message, tx, skip) => {
    return tx.then(async (result) => {
        const receipt = await result.wait();
        if (!skip)
            console.log("           Used", receipt.gasUsed.toNumber(), `gas for >${message}<`);
        return result;
    });
};
exports.logGas = logGas;
const executeTx = async (safe, safeTx, signatures, overrides) => {
    const signatureBytes = (0, exports.buildSignatureBytes)(signatures);
    return safe.execTransaction(safeTx.to, safeTx.value, safeTx.data, safeTx.operation, safeTx.safeTxGas, safeTx.baseGas, safeTx.gasPrice, safeTx.gasToken, safeTx.refundReceiver, signatureBytes, overrides || {});
};
exports.executeTx = executeTx;
const populateExecuteTx = async (safe, safeTx, signatures, overrides) => {
    const signatureBytes = (0, exports.buildSignatureBytes)(signatures);
    return safe.populateTransaction.execTransaction(safeTx.to, safeTx.value, safeTx.data, safeTx.operation, safeTx.safeTxGas, safeTx.baseGas, safeTx.gasPrice, safeTx.gasToken, safeTx.refundReceiver, signatureBytes, overrides || {});
};
exports.populateExecuteTx = populateExecuteTx;
const buildContractCall = (contract, method, params, nonce, delegateCall, overrides) => {
    const data = contract.interface.encodeFunctionData(method, params);
    return (0, exports.buildSafeTransaction)(Object.assign({
        to: contract.address,
        data,
        operation: delegateCall ? 1 : 0,
        nonce,
    }, overrides));
};
exports.buildContractCall = buildContractCall;
const executeTxWithSigners = async (safe, tx, signers, overrides) => {
    const sigs = await Promise.all(signers.map((signer) => (0, exports.safeSignTypedData)(signer, safe, tx)));
    return (0, exports.executeTx)(safe, tx, sigs, overrides);
};
exports.executeTxWithSigners = executeTxWithSigners;
const executeContractCallWithSigners = async (safe, contract, method, params, signers, delegateCall, overrides) => {
    const tx = (0, exports.buildContractCall)(contract, method, params, await safe.nonce(), delegateCall, overrides);
    return (0, exports.executeTxWithSigners)(safe, tx, signers);
};
exports.executeContractCallWithSigners = executeContractCallWithSigners;
const buildSafeTransaction = (template) => {
    return {
        to: template.to,
        value: template.value || 0,
        data: template.data || "0x",
        operation: template.operation || 0,
        safeTxGas: template.safeTxGas || 0,
        baseGas: template.baseGas || 0,
        gasPrice: template.gasPrice || 0,
        gasToken: template.gasToken || constants_1.AddressZero,
        refundReceiver: template.refundReceiver || constants_1.AddressZero,
        nonce: template.nonce,
    };
};
exports.buildSafeTransaction = buildSafeTransaction;
const encodeMetaTransaction = (tx) => {
    const data = ethers_1.utils.arrayify(tx.data);
    const encoded = ethers_1.utils.solidityPack(["uint8", "address", "uint256", "uint256", "bytes"], [tx.operation, tx.to, tx.value, data.length, data]);
    return encoded.slice(2);
};
const encodeMultiSend = (txs) => {
    return "0x" + txs.map((tx) => encodeMetaTransaction(tx)).join("");
};
exports.encodeMultiSend = encodeMultiSend;
const buildMultiSendSafeTx = (multiSend, txs, nonce, overrides) => {
    return (0, exports.buildContractCall)(multiSend, "multiSend", [(0, exports.encodeMultiSend)(txs)], nonce, true, overrides);
};
exports.buildMultiSendSafeTx = buildMultiSendSafeTx;
