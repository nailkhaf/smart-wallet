// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "./interfaces/IGuardian.sol";

contract SmartWallet is IERC165, IERC721Receiver, IERC1155Receiver, IERC1271 {

    address public implementation;
    address public owner;
    address public guardian;
    mapping(address => bool) public modules;

    error InvalidSignatureLength();
    error InvalidSignatureS();
    error InvalidSignatureV();
    error InvalidSignature();
    error InvalidNewOwner();
    error AccessDenied();
    error GuardProtection();
    error FunctionNotImplemented(address sender, bytes4 selector, bytes data);

    event Executed(address indexed target, uint256 value, bytes data);
    event ExecutedFromModule(address indexed module, address indexed target, uint256 value, bytes data);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ModuleAdded(address indexed module);
    event ModuleRemoved(address indexed module);
    event NativeReceived(address indexed from, uint256 value);
    event ERC721Received(address indexed operator, address indexed from, uint256 tokenId);
    event ERC1155Received(address indexed operator, address indexed from, uint256 id, uint256 value);
    event ERC1155BatchReceived(address indexed operator, address indexed from, uint256[] ids, uint256[] values);
    event WalletUpgraded(address indexed newImplementation);
    event GuardianChanged(address indexed guardian);

    modifier onlySelf() {
        if (msg.sender != address(this)) revert AccessDenied();
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert AccessDenied();
        _;
    }

    modifier onlyModule() {
        if (!modules[msg.sender]) revert AccessDenied();
        _;
    }

    function setup(
        address _owner,
        address _guardian,
        address[] calldata _modules
    ) external {
        require(owner == address(0));
        owner = _owner;
        emit OwnershipTransferred(address(0), _owner);

        guardian = _guardian;
        emit GuardianChanged(_guardian);

        uint256 modulesLength = _modules.length;
        for (uint256 i = 0; i < modulesLength; i++) {
            modules[_modules[i]] = true;
            emit ModuleAdded(_modules[i]);
        }

        emit WalletUpgraded(implementation);
    }

    function version() external pure returns(uint256)  {
        return 1;
    }

    function executeFromModule(
        address target,
        uint256 value,
        bytes calldata data
    ) external onlyModule {
        _guard(target, value, data);
        _execute(target, value, data);
        emit ExecutedFromModule(msg.sender, target, value, data);
    }

    function execute(
        address target,
        uint256 value,
        bytes calldata data
    ) external onlyOwner {
        _guard(target, value, data);
        _execute(target, value, data);
        emit Executed(target, value, data);
    }

    function _guard(
        address target,
        uint256 value,
        bytes calldata data
    ) internal {
        if (guardian != address(0)) {
            if (!IGuardian(guardian).validate(target, value, data)) revert GuardProtection();
        }
    }

    function _execute(
        address target,
        uint256 value,
        bytes calldata data
    ) internal returns (bytes memory result) {
        bool success;
        (success, result) = target.call{value : value}(data);
        if (!success) {
            // solhint-disable-next-line no-inline-assembly
            assembly {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }

    function transferOwnership(address newOwner) external onlySelf {
        if (newOwner == address(0)) revert InvalidNewOwner();
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    function upgrade(address newImplementation) external onlySelf {
        implementation = newImplementation;
        emit WalletUpgraded(newImplementation);
    }

    function changeGuardian(address _guardian) external onlySelf {
        guardian = _guardian;
        emit GuardianChanged(_guardian);
    }

    function addModule(address module) external onlySelf {
        modules[module] = true;
        emit ModuleAdded(module);
    }

    function removeModule(address module) external onlySelf {
        modules[module] = false;
        emit ModuleRemoved(module);
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC165).interfaceId
        || interfaceId == type(IERC721Receiver).interfaceId
        || interfaceId == type(IERC1155Receiver).interfaceId;
    }

    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4) {
        if (recoverSigner(hash, signature) == owner) {
            return 0x1626ba7e;
        } else {
            return 0xffffffff;
        }
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata
    ) external override returns (bytes4) {
        emit ERC721Received(operator, from, tokenId);
        return this.onERC721Received.selector;
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata
    ) external override returns (bytes4) {
        emit ERC1155Received(operator, from, id, value);
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata
    ) external override returns (bytes4) {
        emit ERC1155BatchReceived(operator, from, ids, values);
        return this.onERC1155BatchReceived.selector;
    }

    function recoverSigner(
        bytes32 hash,
        bytes memory signature
    ) internal pure returns (address) {
        if (signature.length != 65) revert InvalidSignatureLength();

        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) revert InvalidSignatureS();
        if (v != 27 && v != 28) revert InvalidSignatureV();

        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) revert InvalidSignature();
        return signer;
    }

    fallback() external {
        revert FunctionNotImplemented(msg.sender, msg.sig, msg.data);
    }

    receive() external payable {
        emit NativeReceived(msg.sender, msg.value);
    }
}
