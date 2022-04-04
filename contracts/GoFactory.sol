// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./GoCollectible.sol";

contract GoFactory is Ownable, ReentrancyGuard {
  using Strings for string;
  using SafeMath for uint256;

  address public proxyRegistryAddress;
  address public nftAddress;
  string constant internal baseMetadataURI = "https://opensea-creatures-api.herokuapp.com/api/";
  uint256 constant SUPPLY_PER_TOKEN_ID = 1000;

  /**
   * Three different options for minting GoCollectibles (basic, premium, and gold).
   */
  enum Option { Basic, Premium, Gold }
  mapping (uint256 => uint256) public optionToTokenID;

  constructor(address _proxyRegistryAddress) {
    proxyRegistryAddress = _proxyRegistryAddress;
  }

  function canMint(uint256 _optionId, uint256 _amount) external view returns (bool) {
    return _canMint(msg.sender, Option(_optionId), _amount);
  }

  function mint(uint256 _optionId, address _toAddress, uint256 _amount, bytes calldata _data) external nonReentrant() {
    return _mint(Option(_optionId), _toAddress, _amount, _data);
  }

  /// @param _nftAddress NFT ctt address to delegatecall
  function setNftAddress(address _nftAddress) external onlyOwner {
    nftAddress = _nftAddress;
  }

  function _mint(Option _option, address _toAddress, uint256 _amount, bytes memory _data) internal {
    require(_canMint(msg.sender, _option, _amount), "MyFactory#_mint: CANNOT_MINT_MORE");
    uint256 optionId = uint256(_option);
    GoCollectible nftContract = GoCollectible(nftAddress);
    uint256 id = optionToTokenID[optionId];
    if (id == 0) {
      id = nftContract.create(_toAddress, _amount, _data);
      optionToTokenID[optionId] = id;
    } else {
      nftContract.mint(_toAddress, id, _amount, _data);
    }
  }

  /**
   * Get the factory's ownership of Option.
   * Should be the amount it can still mint.
   * NOTE: Called by `canMint`
   */
  function balanceOf(
    address _owner,
    uint256 _optionId
  ) public view returns (uint256) {
    if (!_isOwnerOrProxy(_owner)) {
      // Only the factory owner or owner's proxy can have supply
      return 0;
    }
    uint256 id = optionToTokenID[_optionId];
    if (id == 0) {
      // Haven't minted yet
      return SUPPLY_PER_TOKEN_ID;
    }

    GoCollectible nftContract = GoCollectible(nftAddress);
    uint256 currentSupply = nftContract.totalSupply(id);
    return SUPPLY_PER_TOKEN_ID.sub(currentSupply);
  }

  /**
   * Hack to get things to work automatically on OpenSea.
   * Use safeTransferFrom so the frontend doesn't have to worry about different method names.
   */
  function safeTransferFrom(
    address _to,
    uint256 _optionId,
    uint256 _amount,
    bytes calldata _data
  ) external {
    _mint(Option(_optionId), _to, _amount, _data);
  }

  function isApprovedForAll(
    address _owner,
    address _operator
  ) public view returns (bool) {
    return owner() == _owner && _isOwnerOrProxy(_operator);
  }

  function _canMint(
    address _fromAddress,
    Option _option,
    uint256 _amount
  ) internal view returns (bool) {
    uint256 optionId = uint256(_option);
    return _amount > 0 && balanceOf(_fromAddress, optionId) >= _amount;
  }

  function _isOwnerOrProxy( address _address ) internal view returns (bool) {
    ProxyRegistry proxyRegistry = ProxyRegistry(proxyRegistryAddress);
    return owner() == _address || address(proxyRegistry.proxies(owner())) == _address;
  }
}
