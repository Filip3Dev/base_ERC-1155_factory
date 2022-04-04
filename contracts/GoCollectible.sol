// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./Token.sol";

/**
 * @title MyCollectible
 * MyCollectible - a contract for my semi-fungible tokens.
 */
contract GoCollectible is GoToken {
  constructor(address _factory) GoToken( "MyCollectible", "MCB", _factory) {
    _setURI("");
  }
}
