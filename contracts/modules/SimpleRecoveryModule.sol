// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../SmartWallet.sol";

contract SimpleRecoveryModule is Ownable {
    struct Recovery {
        address newOwner;
        uint256 recoveryStartedAt;
    }

    error ModuleNotInstalled(address wallet);
    error InvalidNewOwner(address wallet);
    error RecoveryTimeNotPassed();
    error RecoveryNotStarted();

    event RecoveryStarted(address indexed wallet, address indexed newOwner);
    event RecoveryCanceled(address indexed wallet);
    event RecoveryFinished(address indexed wallet);

    uint256 immutable recoveryTime;
    mapping(address => Recovery) public recoveries;

    constructor(uint256 _recoveryTime) {
        recoveryTime = _recoveryTime;
    }

    function startRecovery(address payable wallet, address newOwner) external onlyOwner {
        if (!SmartWallet(wallet).modules(address(this))) revert ModuleNotInstalled(wallet);
        if (newOwner == owner()) revert InvalidNewOwner(wallet);

        recoveries[wallet].newOwner = newOwner;
        recoveries[wallet].recoveryStartedAt = block.timestamp;

        emit RecoveryStarted(wallet, newOwner);
    }

    function cancelRecovery() external {
        uint256 recoveryStartedAt = recoveries[msg.sender].recoveryStartedAt;
        if (recoveryStartedAt == 0) revert RecoveryNotStarted();

        recoveries[msg.sender].newOwner = address(0);
        recoveries[msg.sender].recoveryStartedAt = 0;

        emit RecoveryCanceled(msg.sender);
    }

    function finishRecovery(address payable wallet) external onlyOwner {
        uint256 recoveryStartedAt = recoveries[wallet].recoveryStartedAt;
        if (recoveryStartedAt == 0) revert RecoveryNotStarted();
        if (block.timestamp - recoveryStartedAt < recoveryTime) revert RecoveryTimeNotPassed();

        bytes memory data = abi.encodeWithSelector(
            SmartWallet.transferOwnership.selector, recoveries[wallet].newOwner
        );
        recoveries[msg.sender].newOwner = address(0);
        recoveries[msg.sender].recoveryStartedAt = 0;

        SmartWallet(wallet).executeFromModule(wallet, 0, data);

        emit RecoveryFinished(wallet);
    }
}
