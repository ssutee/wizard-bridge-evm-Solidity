// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

library Structs {
    struct MintInput {
        uint32 sourceChain;
        address token;
        uint256 amount;
        address receiver;
        string wrappedTokenName;
        string wrappedTokenSymbol;
        bytes txHash;
        bytes txSigned;
        uint256 timestamp;
    }

    struct ReleaseInput {
        uint32 sourceChain;
        address token;
        uint256 amount;
        address receiver;
        bytes txHash;
        bytes txSigned;
        uint256 timestamp;
    }

    struct WrappedToken {
        string name;
        string symbol;
        uint8 decimals;
        address wrappedToken;
        address token;
        uint32 sourceChain;
    }
}
