// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../libraries/Structs.sol";

interface IBridge {
    // The bridgeOut (lock) function is used for sending a token from its source chain to any target chain.
    function bridgeOut(uint32 targetChain, address token, uint256 amount) external payable;

    // An event emitted once a Lock transaction is executed
    event Lock(
        uint32 targetChain,
        address token,
        address receiver,
        uint256 amount,
        uint256 serviceFee
    );

    // The mintToBridgeOut (mint) function is used for the creation and release of wrapped tokens in a target chain.
    function mintToBridgeOut(Structs.MintInput memory mintArgs) external;

    // An even emitted once a Mint transaction is executed
    event Mint(
        uint256 sourceChain,
        address wrappedToken, 
        uint256 amount, 
        address receiver, 
        uint256 timestamp
    );

    // The bridgeIn (burn) function is used for sending a wrapped token back into its source chain.
    function bridgeIn(uint32 sourceChain, address wrappedToken, uint256 amount, address receiver) external payable;

    // An event emitted once a Burn transaction is executed
    event Burn(
        address wrappedToken, 
        uint256 amount, 
        address receiver,
        uint32 sourceChain,
        uint256 serviceFee
    );

    // The unlockToBridgeIn (release) function is used for the unlock of tokens when they were sent from other network.
    function unlockToBridgeIn(Structs.ReleaseInput memory args) external;

    // An event emitted once an Unlock transaction is executed
    event Release(
        uint256 sourceChain,
        address token,
        uint256 amount,
        address receiver, 
        uint256 timestamp
    );

    // The wrappedTokens return all the wrapped tokens
    function interfaceTokens() external view returns (Structs.WrappedToken[] memory);

    // An event emitted once a new wrapped token is deployed by the contract
    event WrappedTokenDeployed(
        uint32 sourceChain,
        address token,
        address wrappedToken
    );
}
