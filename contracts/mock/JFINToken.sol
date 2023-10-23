// "SPDX-License-Identifier: MIT"

pragma solidity 0.8.4;

import "./BasicToken.sol";

contract JFINToken is BasicToken {
    constructor() BasicToken("JFIN Token", "JFIN") {}
}
