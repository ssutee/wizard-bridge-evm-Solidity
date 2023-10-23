// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

//                       ▄▄                                 ▄▄                        ▄▄         ▄▄                                                            
// ▀████▀     █     ▀███▀ ██                               ▀███     ▀███▀▀▀██▄         ██       ▀███                     ▀███▀▀▀███▀████▀   ▀███▀████▄     ▄███▀
//  ▀██     ▄██     ▄█                                      ██       ██    ██                    ██                       ██    ▀█  ▀██     ▄█   ████    ████  
//   ██▄   ▄███▄   ▄█  ▀███  █▀▀▀███ ▄█▀██▄ ▀███▄███   ▄█▀▀███       ██    █████▄███▀███    ▄█▀▀███  ▄█▀█████ ▄▄█▀██      ██   █     ██▄   ▄█    █ ██   ▄█ ██  
//    ██▄  █▀ ██▄  █▀    ██  ▀  ███ ██   ██   ██▀ ▀▀ ▄██    ██       ██▀▀▀█▄▄ ██▀ ▀▀  ██  ▄██    ██ ▄██  ██  ▄█▀   ██     ██████      ██▄  █▀    █  ██  █▀ ██  
//    ▀██ █▀  ▀██ █▀     ██    ███   ▄█████   ██     ███    ██       ██    ▀█ ██      ██  ███    ██ ▀█████▀  ██▀▀▀▀▀▀     ██   █  ▄   ▀██ █▀     █  ██▄█▀  ██  
//     ▄██▄    ▄██▄      ██   ███  ▄██   ██   ██     ▀██    ██       ██    ▄█ ██      ██  ▀██    ██ ██       ██▄    ▄     ██     ▄█    ▄██▄      █  ▀██▀   ██  
//      ██      ██     ▄████▄███████▀████▀██▄████▄    ▀████▀███▄   ▄████████▄████▄  ▄████▄ ▀████▀███▄███████  ▀█████▀   ▄██████████     ██     ▄███▄ ▀▀  ▄████▄
//                                                                                                  █▀     ██                                                  
//                                                                                                  ██████▀                                                    

// Website (demo): https://testnet-wizardbridgeevm.web.app
// X: https://twitter.com/wizardbridgeevm
// Docs: https://wizard-bridge-evm.gitbook.io/docs
// Github: https://github.com/Wizard-Bridge-EVM

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "hardhat/console.sol";

import "./libraries/Structs.sol";
import "./interfaces/IBridge.sol";

contract WizardBridgeEVM is IBridge, Ownable, ReentrancyGuard, Pausable {
    mapping(address => Structs.WrappedToken) private _wrappedDetails;
    mapping(address => address) private _tokenToWrapped;
    Structs.WrappedToken[] private _interfaceTokens;
    mapping(uint256 => bool) private _usedTime;
    mapping(bytes => bool) private _usedTxns;
    address private _trustedSigner;
    uint256 private _serviceFee;
    bytes32 private _isValidTx;

    constructor(address trustedSigner, uint256 serviceFee) {
        _trustedSigner = trustedSigner;
        _serviceFee = serviceFee;
    }

    // Checks if the message is siggned from a trusted signer
      // Fact Protocol Interface : (Proof of Message)
    modifier isTrustedSigner(bytes memory msgHash, bytes memory msgSigned) {
        address signer = recoverSignerFromSignedMessage(
            msgHash,
            msgSigned
        );
        require(signer == _trustedSigner, "Bad signer");
        _;
    }

    // Check if function arguments match the txHash
    modifier isValidTx(
        uint32 chainId,
        address token,
        uint256 amount,
        address receiver,
        string memory wTokenName,
        string memory wTokenSymbol,
        uint256 timestamp,
        bytes memory txHash
    ) {
        require(
            hashArgs(
                chainId,
                token,
                amount,
                receiver,
                wTokenName,
                wTokenSymbol,
                timestamp
            ) == bytesToTxHash(txHash),
            "Bad args"
        );
        _;
    }

    function bridgeOut(
        uint32 targetChain,
        address token,
        uint256 amount
    ) external payable override nonReentrant whenNotPaused {
        require(msg.value >= _serviceFee, "Service fee not enough");
        require(amount > 0, "Lock 0");

        IERC20(token).transferFrom(msg.sender, address(this), amount);

        emit Lock(targetChain, address(token), msg.sender, amount, msg.value);
    }

    function mintToBridgeOut(Structs.MintInput memory args)
    external
    override
    nonReentrant
    whenNotPaused
    isTrustedSigner(args.txHash, args.txSigned)
    { // 
    _isValidTx = keccak256(abi.encodePacked(
        args.sourceChain,
        args.token,
        args.amount,
        args.receiver,
        args.wrappedTokenName,
        args.wrappedTokenSymbol,
        args.timestamp,
        args.txHash)
    );
        require(args.receiver == msg.sender, "Receiver and sender mismatch");
        require(args.amount > 0, "Bad amount");
        require(!_usedTime[args.timestamp], "Error (Proof of Message): Duplicate or already used");
        require(!_usedTxns[args.txHash], "Error (Proof of Message): Duplicate or already used");

        address wrappedToken = _tokenToWrapped[args.token];
        if (wrappedToken == address(0)) {
        // First interface
        wrappedToken = wrapToken(
            args.sourceChain,
            args.token,
            args.wrappedTokenName,
            args.wrappedTokenSymbol);
        }
        ERC20PresetMinterPauser(wrappedToken).mint(msg.sender, args.amount);

        _usedTime[args.timestamp] = true;
        _usedTxns[args.txHash] = true;

        emit Mint(args.sourceChain, _tokenToWrapped[args.token], args.amount, msg.sender, block.timestamp);
    }

    function bridgeIn(
        uint32 sourceChain,
        address wrappedToken,
        uint256 amount,
        address receiver
    ) external override payable nonReentrant whenNotPaused {
        require(msg.value >= _serviceFee, "Service fee not enough");
        require(receiver == msg.sender, "Receiver and sender mismatch");
        ERC20Burnable token = ERC20Burnable(wrappedToken);
        require(amount > 0, "Bad amount");
        require(
        _wrappedDetails[wrappedToken].token != address(0),
        "Not supported token"
        );
        require(
        _wrappedDetails[wrappedToken].sourceChain == sourceChain,
        "Bad source chain"
        );

        token.burnFrom(receiver, amount);

        emit Burn(wrappedToken, amount, msg.sender, sourceChain, msg.value);
    }

    function unlockToBridgeIn(Structs.ReleaseInput memory args)
    external
    override
    nonReentrant
    whenNotPaused
    isTrustedSigner(args.txHash, args.txSigned)
    isValidTx(
        args.sourceChain,
        args.token,
        args.amount,
        args.receiver,
        "",
        "",
        args.timestamp,
        args.txHash)
    {
        require(args.receiver == msg.sender, "Receiver and sender mismatch");
        require(isContract(args.token), "Token does not exist");
        require(!_usedTime[args.timestamp], "Error (Proof of Message): Duplicate or already used");
        require(!_usedTxns[args.txHash], "Error (Proof of Message): Duplicate or already used");

        IERC20(args.token).transfer(msg.sender, args.amount);

        _usedTime[args.timestamp] = true;
        _usedTxns[args.txHash] = true;

        emit Release(args.sourceChain, args.token, args.amount, msg.sender, block.timestamp);
    }

    // ** //
    function wrapToken(
        uint32 sourceChain,
        address token,
        string memory name,
        string memory symbol
    ) internal returns (address) {
        require(_tokenToWrapped[token] == address(0), "Already wrapped");
        require(bytes(name).length != 0, "Bad name");
        require(bytes(symbol).length != 0, "Bad symbol");
        require(sourceChain > 0, "Bad chain id");

        ERC20PresetMinterPauser wrappedToken = new ERC20PresetMinterPauser(
            name,
            symbol
        );

        wrappedToken.grantRole(keccak256("DEFAULT_ADMIN_ROLE"), address(this));

        _tokenToWrapped[token] = address(wrappedToken);
        Structs.WrappedToken memory storeIt = Structs.WrappedToken({
            name: name,
            symbol: symbol,
            decimals: wrappedToken.decimals(),
            wrappedToken: address(wrappedToken),
            token: token,
            sourceChain: sourceChain
        });

        _interfaceTokens.push(storeIt);
        _wrappedDetails[address(wrappedToken)] = storeIt;

        emit WrappedTokenDeployed(sourceChain, token, address(wrappedToken));

        return address(wrappedToken);
    }

    function interfaceTokens()
        external
        view
        override
        returns (Structs.WrappedToken[] memory)
    {
        return _interfaceTokens;
    }
    // ================================================================ //
    // Function to update the service fee
    function updateServiceFee(uint256 newFee) external onlyOwner {
        _serviceFee = newFee;
    }

    // Function to withdraw eth from the contract
    function withdrawFees() external onlyOwner {
        require(address(this).balance > 0, "No balance to withdraw");
        payable(msg.sender).transfer(address(this).balance);
    }

    //** Function safety in case of emergency (whenNotPaused) **//
    function pauseEmergency() external onlyOwner {
        _pause();
    }

    function unpauseEmergency() external onlyOwner {
        _unpause();
    }

    //** **//
    receive() external payable {
        revert("Reverted");
    }

    fallback() external payable {
        revert("Reverted");
    }

    function recoverSignerFromSignedMessage(
        bytes memory hashedMessage,
        bytes memory signedMessage
    ) internal pure returns (address) {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = splitSignature(signedMessage);

        address signer = recoverSigner(hashedMessage, v, r, s);
        require(signer != address(0), "ECDSA: invalid signature");

        return signer;
    }

    function recoverSigner(
        bytes memory hashedMessage,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address) {
        bytes32 messageDigest = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", hashedMessage)
        );

        return ecrecover(messageDigest, v, r, s);
    }

    function splitSignature(bytes memory sig)
        internal
        pure
        returns (
            uint8,
            bytes32,
            bytes32
        )
    {
        require(sig.length == 65, "Invalid signature length");

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }

        return (v, r, s);
    }

    function hashArgs(
        uint32 sourceChain,
        address nativeToken,
        uint256 amount,
        address receiver,
        string memory wTokenName,
        string memory wTokenSymbol,
        uint256 timestamp
    ) internal view returns (bytes32 hash) {
        hash =        
            keccak256(
                abi.encodePacked(
                    sourceChain,
                    nativeToken,
                    amount,
                    receiver,
                    wTokenName,
                    wTokenSymbol,
                    timestamp
                )
            );
        console.logBytes32(hash);
    }

    function bytesToAddress(bytes memory bys)
        internal
        pure
        returns (address addr)
    {
        assembly {
            addr := mload(add(bys, 20))
        }
    }

    function bytesToTxHash(bytes memory bys)
        internal
        pure
        returns (bytes32 txHash)
    {
        assembly {
            txHash := mload(add(bys, 32))
        }
    }

    function isContract(address addr) internal view returns (bool) {
        uint256 size;

        assembly {
            size := extcodesize(addr)
        }

        return size > 0;
    }
}
