// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IGuardian {

    function validate(
        address target,
        uint256 value,
        bytes calldata data
    ) external returns (bool);
}
