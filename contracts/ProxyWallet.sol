// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/Proxy.sol";

contract ProxyWallet is Proxy {

    address public implementation;

    constructor(address implementation_) payable {
        implementation = implementation_;
    }

    function _implementation() internal view override returns (address) {
        return implementation;
    }
}
