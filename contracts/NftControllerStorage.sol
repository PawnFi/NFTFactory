// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./interfaces/INftController.sol";

abstract contract NftControllerStorage is INftController {

    /// @notice Staker role that supports NFTID staking keccak256("STAKER_ROLE")
    bytes32 public constant override STAKER_ROLE = 0xb9e206fa2af7ee1331b72ce58b6d938ac810ce9b5cdb65d35ab723fd67badf9e;

    /// @notice NFT fraction amount, 1 NFT = pieceCount ptoken
    uint256 public override pieceCount;

    /// @notice When swapping NFTs randomly, calculate the index of the random NFT id
    address public override randomTool;

    /// @notice Parameter configuration when swapping NFT (general config)
    ConfigInfo public override configInfo;

    /// @notice Whether to enable customized parameter config for NFT <nft_addr,true/false> true:customized config,false:general config
    mapping(address => bool) public override enableConfig;

    // Parameter configuration when swapping NFT <nft_addr,ConfigInfo>
    mapping(address => ConfigInfo) internal _nftConfig;

    /// @notice Whether to allow random NFT to swap ptoken true:not allow false:allow
	bool public override openControl;

    /// @notice Whitelist for NFT to create ptoken <nft_addr,true/false> true:allow false:not allow
    mapping(address => bool) public override whitelist;

    /// @notice Whether to allow every NFT IDs to swap ptoken <nft_addr,true/false> true:not allow,false:allow
    mapping(address => bool) public override nftBlackList;

    /// @notice Whether to allow specific NFT ID to swap ptoken <nftaddr,<nftid,bool> >  true:not allow false:allow
    mapping(address => mapping(uint256 => bool)) public override nftIdBlackList;
}
