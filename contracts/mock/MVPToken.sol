// "SPDX-License-Identifier: MIT"

pragma solidity 0.8.4;

import "./BasicToken.sol";

contract MVPToken is BasicToken {
    constructor() BasicToken("MVP Token", "MVP") {}
}
