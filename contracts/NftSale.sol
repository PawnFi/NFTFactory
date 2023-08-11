// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./libraries/TransferHelper.sol";
import "./interfaces/IPToken.sol";
import "./interfaces/IPTokenFactory.sol";
import "./NftSaleStorage.sol";

/**
 * @title NNFT consign/leverage contract
 * @notice Supports NFT consign/purchase/redeem, and leverage/repay functions
 * @author Pawnfi
 */
contract NftSale is AccessControlUpgradeable, ERC721HolderUpgradeable, NftSaleStorage {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;

    /**
     * @notice Initialize contract
     * @param admin_ Owner
     * @param feeTo_ Platform fee address
     * @param factory_ ptoken factory contract address
     * @param saleCommissionRate_ Commission fee rate for consign spread
     * @param lockInfo_ All order information of consign/leverage
     */
    function initialize(address admin_, address feeTo_, address factory_, uint256 saleCommissionRate_, LockInfo memory lockInfo_) external initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, admin_);
        feeTo = feeTo_;
        factory = factory_;
        saleCommissionRate = saleCommissionRate_;
        lockInfo = lockInfo_;
    }

    /**
     * @notice Get ptoken address
     * @param nftAddr nft contract address
     * @return pieceToken ptoken contract address
     */
    function getPieceToken(address nftAddr) public view returns (address pieceToken) {
        pieceToken = IPTokenFactory(factory).getPiece(nftAddr);
    }

    /**
     * @notice Create Nft consign/leverage order with router (create to settle in tokens other than ptoken)
     * @param creator Creator address(nft owner)
     * @param nftAddr nft contract address
     * @param nftId nft id
     * @param blockCount Block numbers for lock-up
     * @param salePrice Sale price (0 when leverage)
     */
    function delegateCreate(address creator, address nftAddr, uint256 nftId, uint256 blockCount, uint256 salePrice) external virtual override {
        require(hasRole(DELEGATE_ROLE, msg.sender), "caller is missing role");
        _create(creator, nftAddr, nftId, blockCount, salePrice);
    }

    /**
     * @notice Create Nft consign/leverage order
     * @param nftAddr nft contract address
     * @param nftId nft id
     * @param blockCount Block numbers for lock-up
     * @param salePrice Sale price (0 when leverage)
     */
    function create(address nftAddr, uint256 nftId, uint256 blockCount, uint256 salePrice) external virtual override onlyEOA {
        _create(msg.sender, nftAddr, nftId, blockCount, salePrice);
    }

    /**
     * @notice Create Nft consign/leverage order
     * @param creator Creator address(nft owner)
     * @param nftAddr nft contract address
     * @param nftId nft id
     * @param blockCount Block numbers for lock-up
     * @param salePrice Sale price (0 when leverage)
     */
    function _create(address creator, address nftAddr, uint256 nftId, uint256 blockCount, uint256 salePrice) private {
        LockInfo memory info = nftLockInfo(nftAddr);
        address pToken = getPieceToken(nftAddr);
        uint256 pieceCount = IPToken(pToken).pieceCount();
        require(blockCount > 0 && blockCount <= info.lockMaxBlockNumber, "LOCK TIME ERROR");
        require(salePrice == 0 || salePrice > pieceCount, "SALE PRICE TOO LOW");

        uint256 endBlock = blockCount.add(block.number);
        // Extend the locking period
        // Height of ending block = locking period * 0.2 + height of current block
        uint256 lockEndBlock = blockCount.mul(info.lockBlockExtendRate).div(BASE_PERCENTS).add(endBlock);
        uint256 lockFee = getPreLockFee(nftAddr, blockCount);
        uint256 tokenAmount = _deposit(msg.sender, nftAddr, nftId, lockEndBlock);

        uint256 piecePayed = tokenAmount.sub(lockFee);
        SaleInfo memory saleInfo = SaleInfo({
            userAddr: creator,
            nftAddr: nftAddr,
            nftId: nftId,
            salePrice: salePrice,
            startBlock: block.number,
            endBlock: endBlock,
            lockEndBlock: lockEndBlock,
            lockFeeRate: info.lockFeeRate,
            lockFeePayed: lockFee,
            piecePayed: piecePayed
        });

        saleIndex[nftAddr][nftId] = allInfo.length;
        allInfo.push(saleInfo);
        IERC20Upgradeable(pToken).safeTransfer(msg.sender, piecePayed);
        emit CreateSale(creator, nftAddr, nftId, blockCount, salePrice, lockEndBlock, lockFee);
    }

    function _deposit(address sender, address nftAddr, uint256 nftId, uint256 blockNumber) private returns (uint256) {
        address pieceToken = getPieceToken(nftAddr);
        TransferHelper.transferInNonFungibleToken(IPTokenFactory(factory).nftTransferManager(), nftAddr, sender, address(this), nftId);
        TransferHelper.approveNonFungibleToken(IPTokenFactory(factory).nftTransferManager(), nftAddr, address(this), pieceToken, nftId);
        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = nftId;
        return IPToken(pieceToken).deposit(nftIds, blockNumber);
    }

    /**
     * @notice Update platform fee address
     * @param newFeeTo New platform fee address
     */
    function setFeeTo(address newFeeTo) external virtual override {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "caller is missing role");
        feeTo = newFeeTo;
    }

    /**
     * @notice Update commission fee rate for consign spread
     * @param newSaleCommissionRate New commission fee rate for consign spread
     */
    function setSaleCommissionRate(uint256 newSaleCommissionRate) external virtual override {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "caller is missing role");
        saleCommissionRate = newSaleCommissionRate;
    }

    /**
     * @notice Update general lock-up configuration
     * @param newLockInfo New general lock-up info
     */
    function setLockInfo(LockInfo memory newLockInfo) external virtual override {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "caller is missing role");
        lockInfo = newLockInfo;
    }

    /**
     * @notice Update lock-up configuration for single NFT
     * @param nftAddr nft contract address
     * @param newLockInfo lock-up configuration
     * @param enable Whether the nft uses a customized lock-up configuration true:customized false:not customized
     */
    function setNftLockInfo(address nftAddr, LockInfo memory newLockInfo, bool enable) external virtual override {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "caller is missing role");
        enableLockInfo[nftAddr] = enable;
        _nftLockInfo[nftAddr] = newLockInfo;
    }

    /**
     * @notice Get lock-up configuration for single NFT
     * @param nftAddr nft contract address
     * @return LockInfo Lock-up configuration
     */
    function nftLockInfo(address nftAddr) public view virtual override returns (LockInfo memory) {
        if(enableLockInfo[nftAddr]) {
            return _nftLockInfo[nftAddr];
        } else {
            return lockInfo;
        }
    }

    /**
     * @notice Calculate the prepaid fee required to redeem a locked NFT
     * @param nftAddr nft contract address
     * @param lockBlockNumber Block numbers for lock-up
     * @return fee Lock-up fee
     */
    function getPreLockFee(address nftAddr, uint256 lockBlockNumber) public view virtual override returns (uint256 fee) {
        LockInfo memory info = nftLockInfo(nftAddr);
        address pToken = getPieceToken(nftAddr);
        uint256 pieceCount = IPToken(pToken).pieceCount();
        fee = pieceCount.mul(info.lockFeeRate).mul(lockBlockNumber).mul(info.lockFeePayedRate).div(BASE_PERCENTS).div(BASE_PERCENTS);
    }

    /**
     * @notice Purchase consigned Nft
     * @param nftAddr nft contract address
     * @param nftId nftId
     */
    function buy(address nftAddr, uint256 nftId) external virtual override {
        require(tx.origin == msg.sender || hasRole(DELEGATE_ROLE, msg.sender));
        uint256 infoIndex = saleIndex[nftAddr][nftId];
        require(infoIndex < allInfo.length, "index out of bounds");

        SaleInfo memory saleInfo = allInfo[infoIndex];
        require(saleInfo.startBlock < block.number, "prohibit same block operate");
        require(saleInfo.endBlock >= block.number, "SALE TIMEOUT");
        require(saleInfo.salePrice > 0, "SALE INFO NOT EXIST");
        require(saleInfo.userAddr != msg.sender, "caller isn't creator");

        allInfo[infoIndex].endBlock = 0;

        address pieceToken = getPieceToken(nftAddr);

        IERC20Upgradeable(pieceToken).safeTransferFrom(msg.sender, address(this), saleInfo.salePrice);

        //Redeem the NFT and transfer to the address specified by the purchaser
        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = nftId;
        uint256 tokenAmount = IPToken(pieceToken).withdraw(nftIds);
        uint256 fee = getLockFee(infoIndex, block.number);
        allInfo[infoIndex].lockFeePayed = fee;

        //Calculate sales commission
        uint256 saleCommission = saleInfo.salePrice.sub(tokenAmount).mul(saleCommissionRate).div(BASE_PERCENTS);
        //Calculate the earnings that users can withdraw
        uint256 pieceWithdraw = saleInfo.salePrice.sub(saleInfo.piecePayed).sub(fee).sub(saleCommission);

        //transfer the earnings to initiator directly
        IERC20Upgradeable(pieceToken).safeTransfer(saleInfo.userAddr, pieceWithdraw);
        IERC20Upgradeable(pieceToken).safeTransfer(feeTo, saleCommission.add(fee));

        TransferHelper.transferOutNonFungibleToken(IPTokenFactory(factory).nftTransferManager(), nftAddr, address(this), msg.sender, nftId);

        emit Buy(msg.sender, nftAddr, nftId, fee, saleCommission, pieceWithdraw);
    }

    /**
     * @notice Redeem Nft
     * @param nftAddr nft contract address
     * @param nftId nftId
     */
    function redeem(address nftAddr, uint256 nftId) external virtual override onlyEOA {
        uint256 infoIndex = saleIndex[nftAddr][nftId];
        require(infoIndex < allInfo.length, "index out of bounds");
        SaleInfo memory saleInfo = allInfo[infoIndex];
        require(saleInfo.startBlock < block.number, "prohibit same block operate");
        require(saleInfo.endBlock > 0, "SALE INFO NOT EXISTS"); //Not bought or redeemed
        require(saleInfo.lockEndBlock >= block.number, "LOCK TIMEOUT");

        allInfo[infoIndex].endBlock = 0; //Set as redeemed

        require(saleInfo.userAddr == msg.sender, "USER ERROR"); //must be initiator

        address pieceToken = getPieceToken(saleInfo.nftAddr);

        uint256 fee = getLockFee(infoIndex, block.number);
        uint256 pieceCount = IPToken(pieceToken).pieceCount();
        IERC20Upgradeable(pieceToken).safeTransferFrom(msg.sender, address(this), pieceCount.sub(saleInfo.lockFeePayed).add(fee));
        IERC20Upgradeable(pieceToken).safeTransfer(feeTo, fee);

        //redeem specified NFT(authorize first)
        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = saleInfo.nftId;
        uint256 tokenAmount = IPToken(pieceToken).withdraw(nftIds);

        TransferHelper.transferOutNonFungibleToken(IPTokenFactory(factory).nftTransferManager(), nftAddr, address(this), msg.sender, nftId);

        emit Redeem(msg.sender, tokenAmount, fee, saleInfo.nftAddr, saleInfo.nftId);
    }

    /**
     * @notice Calculate the cost to redeem a locked NFT
     * @param index Order index
     * @param blockNumber End block height
     * @return fee Lock-up fee
     */
    function getLockFee(uint256 index, uint256 blockNumber) public view virtual override returns (uint256 fee) {
        SaleInfo memory saleInfo = allInfo[index];
        address pToken = getPieceToken(saleInfo.nftAddr);
        uint256 pieceCount = IPToken(pToken).pieceCount();
        fee = pieceCount.mul(saleInfo.lockFeeRate).mul(blockNumber.sub(saleInfo.startBlock)).div(BASE_PERCENTS);
    }

    /**
     * @notice Get Nft sale order information
     * @param nftAddr nft contract address
     * @param nftId nftId
     * @return SaleInfo
     */
    function getNftSaleInfo(address nftAddr, uint256 nftId) external view virtual override returns(SaleInfo memory) {
        uint256 infoIndex = saleIndex[nftAddr][nftId];
        if(infoIndex < allInfo.length) {
            SaleInfo memory saleInfo = allInfo[infoIndex];
            if(saleInfo.salePrice > 0 && saleInfo.nftAddr == nftAddr && saleInfo.nftId == nftId && saleInfo.endBlock >= block.number) {
                return saleInfo;
            }
        }
    }

    /**
     * @notice Get the owner address of nft id
     * @param nftAddr nft address
     * @param nftId nft id
     * @return address owner address
     */
    function nftOwner(address, address nftAddr, uint256 nftId) external view returns(address) {
        uint256 infoIndex = saleIndex[nftAddr][nftId];
        if(infoIndex < allInfo.length) {
            SaleInfo memory saleInfo = allInfo[infoIndex];
            if(saleInfo.nftAddr == nftAddr && saleInfo.nftId == nftId && saleInfo.lockEndBlock >= block.number) {
                return saleInfo.userAddr;
            }
        }
        return address(0);
    }

    /**
     * @notice Withdraw platform fee (Initial prepaid fee from liquidated NFT)
     * @param token ptoken address
     * @param amount Withdraw amount
     */
    function withdrawFee(address token, uint256 amount) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "caller isn't admin");
        IERC20Upgradeable(token).safeTransfer(feeTo, amount);
    }

    modifier onlyEOA() {
        require(tx.origin == msg.sender, "Only EOA");
        _;
    }
}