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

// Website (demo): https://testnet--wizard-bridge-evm.web.app
// X: https://twitter.com/wizardbridgeevm
// Docs: https://wizard-bridge-evm.gitbook.io/docs
// Github: https://github.com/Wizard-Bridge-EVM

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./IBridge.sol";
import "./Structs.sol";
import "./Utils.sol";

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
        address signer = Utils.recoverSignerFromSignedMessage(
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
            Utils.hashArgs(
                chainId,
                token,
                amount,
                receiver,
                wTokenName,
                wTokenSymbol,
                timestamp
            ) == Utils.bytesToTxHash(txHash),
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
        require(Utils.isContract(args.token), "Token does not exist");
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
}
