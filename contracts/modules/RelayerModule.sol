// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import "../BaseWallet.sol";

contract TrustedForwarderModule is ERC2771Context {

    error AccessDenied();

    event MessageForwarded(address indexed wallet);

    constructor(address trustedForwarder) ERC2771Context(trustedForwarder) {
    }

    function forward(
        address wallet,
        address target,
        uint256 value,
        bytes calldata data
    ) external {
        if (SmartWallet(wallet).owner() != _msgSender()) revert AccessDenied();
        SmartWallet(wallet).executeFromModule(target, value, data);
        emit MessageForwarded(wallet);
    }
}
