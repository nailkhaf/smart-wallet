// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./SmartWallet.sol";
import "./ProxyWallet.sol";

contract SmartWalletFactory {

    address implementation;

    event WalletDeployed(address indexed wallet, address indexed deployer, string name);

    constructor(address _implementation) {
        implementation = _implementation;
    }

    function deployWallet(
        string memory name,
        address owner,
        address guardian,
        address[] calldata modules
    ) external {
        ProxyWallet wallet = new ProxyWallet{salt: keccak256(abi.encode(msg.sender, keccak256(bytes(name))))}(implementation);
        SmartWallet(payable(address(wallet))).setup(owner, guardian, modules);
        emit WalletDeployed(address(wallet), msg.sender, name);
    }
}
