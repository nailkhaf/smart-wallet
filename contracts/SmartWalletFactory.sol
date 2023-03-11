// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./SmartWallet.sol";

contract SmartWalletFactory {
    using Clones for address;

    address implementation;

    event WalletDeployed(address indexed wallet, address indexed deployer, bytes32 indexed salt);

    constructor(address _implementation) {
        implementation = _implementation;
    }

    function deployWallet(
        bytes32 salt,
        address owner,
        address guardian,
        address[] calldata modules
    ) external {
        address wallet = implementation.cloneDeterministic(keccak256(abi.encode(msg.sender, salt)));
        SmartWallet(payable(wallet)).setup(owner, guardian, modules);
        emit WalletDeployed(wallet, msg.sender, salt);
    }
}
