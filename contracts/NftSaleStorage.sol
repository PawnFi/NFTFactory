// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./interfaces/INftSale.sol";

abstract contract NftSaleStorage is INftSale {

    /// @notice Constants used in calculation
    uint256 public constant BASE_PERCENTS = 1e18;

    /// @notice Name of delegator role that creates consign/leverage order keccak256("DELEGATE_ROLE")
    bytes32 public constant override DELEGATE_ROLE = 0x1a82baf2b928242f69f7147fb92490c6288d044f7257b88817e6284f1eec0f15;

    /// @notice Platform fee address
    address public override feeTo;

    /// @notice ptoken factory contract address
    address public override factory;

    /// @notice Commission fee rate for consign spread
    uint256 public override saleCommissionRate;

    /// @notice All order information of consign/leverage
    SaleInfo[] public override allInfo;

    /// @notice Consign/leverage order index information <nftAddr <nftid,arrayindex> >
    mapping(address => mapping(uint256 => uint256)) public override saleIndex;

    /// @notice General lock-up configuration
    LockInfo public override lockInfo;

    /// @notice Whether the nft uses a customized lock-up configuration <nftaddr,true/false>  true:customized false:not customized
	mapping(address => bool) public enableLockInfo;

    // The customized lock-up configuration for NFT <nftaddr,lock-up configuration>
    mapping(address => LockInfo) internal _nftLockInfo;
}
