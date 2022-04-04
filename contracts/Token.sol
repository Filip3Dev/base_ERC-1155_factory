// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract OwnableDelegateProxy {}

contract ProxyRegistry {
  mapping(address => OwnableDelegateProxy) public proxies;
}

contract GoToken is ERC1155, Pausable, Ownable {
  using Counters for Counters.Counter;
  Counters.Counter private tokenId;
  using Strings for string;
  using SafeMath for uint256;

  address proxyRegistryAddress;
  address private factory;
  mapping(uint256 => address) public creators;
  mapping(uint256 => uint256) public tokenSupply;

  // Contract name
  string public name;
  // Contract symbol
  string public symbol;

  modifier creatorOnly(uint256 _id) {
      require(
          creators[_id] == msg.sender,
          "ERC1155Tradable#creatorOnly: ONLY_CREATOR_ALLOWED"
      );
      _;
  }
  modifier ownersOnly(uint256 _id) {
      require(
          balanceOf(msg.sender, _id) > 0,
          "ERC1155Tradable#ownersOnly: ONLY_OWNERS_ALLOWED"
      );
      _;
  }
  modifier onlyFactory() {
    require(factory == msg.sender, "Only Factory can call the method");
    _;
  }

  constructor( string memory _name, string memory _symbol, address _factory) ERC1155("") {
    name = _name;
    symbol = _symbol;
    factory = _factory;
  }

  /**
    * @dev Returns the total quantity for a token ID
    * @param _id uint256 ID of the token to query
    * @return amount of token in existence
    */
  function totalSupply(uint256 _id) public view returns (uint256) {
    return tokenSupply[_id];
  }
  /**
   * @dev Will update the base URL of token's URI
   * @param _newBaseMetadataURI New base URL of token's URI
   */
  function setBaseMetadataURI( string memory _newBaseMetadataURI ) public onlyFactory {
    _setURI(_newBaseMetadataURI);
  }

  function pause() public onlyFactory {
    _pause();
  }

  function unpause() public onlyFactory {
    _unpause();
  }

  /// @param _factory factory address to delegatecall, mint tokens
  function setFactory(address _factory) public onlyOwner {
    factory = _factory;
  }

  /**
  * @dev Creates a new token type and assigns _initialSupply to an address
  * NOTE: remove onlyOwner if you want third parties to create new tokens on your contract (which may change your IDs)
  * @param _initialOwner address of the first owner of the token
  * @param _initialSupply amount to supply the first owner
  * @param _data Data to pass if receiver is contract
  * @return The newly created token ID
  */
  function create(address _initialOwner, uint256 _initialSupply, bytes calldata _data ) external onlyFactory returns (uint256) {

    uint256 _id = tokenId.current();
    tokenId.increment();
    creators[_id] = msg.sender;

    _mint(_initialOwner, _id, _initialSupply, _data);
    tokenSupply[_id] = _initialSupply;
    return _id;
  }

   /**
    * @dev Mints some amount of tokens to an address
    * @param _to          Address of the future owner of the token
    * @param _id          Token ID to mint
    * @param _quantity    Amount of tokens to mint
    * @param _data        Data to pass if receiver is contract
    */
  function mint(address _to, uint256 _id,uint256 _quantity,bytes memory _data) public creatorOnly(_id) {
    _mint(_to, _id, _quantity, _data);
    tokenSupply[_id] = tokenSupply[_id].add(_quantity);
  }

  /**
    * @dev Mint tokens for each id in _ids
    * @param _to          The address to mint tokens to
    * @param _ids         Array of ids to mint
    * @param _quantities  Array of amounts of tokens to mint per id
    * @param _data        Data to pass if receiver is contract
    */
  function batchMint( address _to, uint256[] memory _ids, uint256[] memory _quantities, bytes memory _data) public {
    for (uint256 i = 0; i < _ids.length; i++) {
      uint256 _id = _ids[i];
      require(creators[_id] == msg.sender, "ERC1155Tradable#batchMint: ONLY_CREATOR_ALLOWED");
      uint256 quantity = _quantities[i];
      tokenSupply[_id] = tokenSupply[_id].add(quantity);
    }
    _mintBatch(_to, _ids, _quantities, _data);
  }
  
  /**
    * @dev Change the creator address for given tokens
    * @param _to   Address of the new creator
    * @param _ids  Array of Token IDs to change creator
    */
  function setCreator( address _to, uint256[] memory _ids ) public {
    require(_to != address(0), "ERC1155Tradable#setCreator: INVALID_ADDRESS.");
    for (uint256 i = 0; i < _ids.length; i++) {
      uint256 id = _ids[i];
      _setCreator(_to, id);
    }
  }

  /**
   * Override isApprovedForAll to whitelist user's OpenSea proxy accounts to enable gas-free listings.
   */
  function isApprovedForAll( address _owner, address _operator) public view override returns (bool isOperator) {
    // Whitelist OpenSea proxy contract for easy trading.
    ProxyRegistry proxyRegistry = ProxyRegistry(proxyRegistryAddress);
    if (address(proxyRegistry.proxies(_owner)) == _operator) {
      return true;
    }
    if (address(0x207Fa8Df3a17D96Ca7EA4f2893fcdCb78a304101) == _operator) {
      return true;
    }

    return ERC1155.isApprovedForAll(_owner, _operator);
  }

  /**
    * @dev Change the creator address for given token
    * @param _to   Address of the new creator
    * @param _id  Token IDs to change creator of
    */
  function _setCreator(address _to, uint256 _id) internal creatorOnly(_id){
    creators[_id] = _to;
  }

  /**
    * @dev Returns whether the specified token exists by checking to see if it has a creator
    * @param _id uint256 ID of the token to query the existence of
    * @return bool whether the token exists
    */
  function _exists( uint256 _id ) internal view returns (bool) {
    return creators[_id] != address(0);
  }

  function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) internal override whenNotPaused {
    super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
  }
  
  function onERC1155Received(address, address, uint256, uint256, bytes memory) public virtual returns (bytes4) {
    return this.onERC1155Received.selector;
  }

  function onERC1155BatchReceived(address, address, uint256[] memory, uint256[] memory, bytes memory) public virtual returns (bytes4) {
    return this.onERC1155BatchReceived.selector;
  }
}
