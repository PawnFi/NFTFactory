// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface INftSale {

    /**
     * @notice Configuration information when NFT is locked
     * @member lockFeeRate Lock fee per block
     * @member lockFeePayedRate Rate of prepaid lockup fee
     * @member lockBlockExtendRate Lock time extension ratio
     * @member lockMaxBlockNumber Maximum number of locked blocks
     */
    struct LockInfo {
        uint256 lockFeeRate;
        uint256 lockFeePayedRate;
        uint256 lockBlockExtendRate;
        uint256 lockMaxBlockNumber;
    }

    /**
     * @notice NFT consign/ leverage order info
     * @member userAddr User address 
     * @member nftAddr NFT token address
     * @member nftId NFT token ID
     * @member salePrice Consign sale price (0 when leverage)
     * @member startBlock Consign/ leverage strating block height
     * @member endBlock Consign/ leverage ending block height
     * @member lockEndBlock Lock ending block height
     * @member lockFeeRate Fee rate
     * @member lockFeePayed Prepaid fee
     * @member piecePayed Upfront payment  
     */
    struct SaleInfo {
        address userAddr;
        address nftAddr;
        uint256 nftId;
        uint256 salePrice;
        uint256 startBlock;
        uint256 endBlock;
        uint256 lockEndBlock;
        uint256 lockFeeRate;
        uint256 lockFeePayed;
        uint256 piecePayed;
    }

    /// @notice Emitted when create consign or leverage order
    event CreateSale(address indexed creator, address indexed nftAddr, uint256 nftId, uint256 blockCount, uint256 salePrice, uint256 endBlock, uint256 lockFee);
    
    /// @notice Emitted when consign order is matched
    event Buy(address buyer, address nftAddr, uint256 nftId, uint256 pieceFee, uint256 pieceCommission, uint256 pieceWithdraw);
    
    /// @notice Emitted when redeem consigned or leveraged NFT
    event Redeem(address redeemer, uint256 pieceCapital, uint256 pieceFee, address nftAddr, uint256 nftid);

    /*** User Interface ***/
    function DELEGATE_ROLE() external view returns(bytes32);
    function feeTo() external view returns(address);
    function factory() external view returns(address);
    function saleCommissionRate() external view returns(uint256);
    function allInfo(uint256) external view returns(address, address, uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256);
    function saleIndex(address, uint256) external view returns(uint256);
    function delegateCreate(address userAddr, address nftAddr, uint256 nftId, uint256 blockCount, uint256 salePrice) external;
    function create(address,uint256,uint256,uint256) external;
    function buy(address,uint256) external;    
    function redeem(address,uint256) external;
    function getNftSaleInfo(address nftAddr, uint256 nftId) external view returns(SaleInfo memory);
    function lockInfo() external view returns(uint256, uint256, uint256, uint256);
    function nftLockInfo(address nftAddr) external view returns(LockInfo memory);
    function getPreLockFee(address nftAddr, uint256 lockBlockNumber) external view returns(uint256 fee);
    function getLockFee(uint256 index, uint256 blockNumber) external view returns(uint256 fee);

    /*** Admin Functions ***/
    function setFeeTo(address newFeeTo) external;
    function setSaleCommissionRate(uint256 newSaleCommissionRate) external;    
    function setLockInfo(LockInfo memory newLockInfo) external;
    function setNftLockInfo(address nftAddr, LockInfo memory newLockInfo, bool enable) external;
}
