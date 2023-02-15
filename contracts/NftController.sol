// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "./interfaces/IRandomTool.sol";
import "./NftControllerStorage.sol";

/**
 * @title NFT manager contract
 * @notice Control the creation, swap, and other contract call ptoken interface permissions of the NFT's corresponding ptoken
 * @author Pawnfi
 */
contract NftController is AccessControlUpgradeable, NftControllerStorage {
    using SafeMathUpgradeable for uint256;

    /**
     * @notice Initialize parameters
     * @param admin_ Owner
     * @param pieceCount_ NFT fraction amount
     * @param randomTool_ Random calculation contract address
     * @param configInfo_ Exchange rate information, including the fee rate for swapping random NFTs and the fee rate swapping specific NFT
     */
    function initialize(address admin_, uint256 pieceCount_, address randomTool_, ConfigInfo memory configInfo_) external initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, admin_);
        pieceCount = pieceCount_;
        randomTool = randomTool_;
        configInfo = configInfo_;
    }

    /**
     * @notice Update the contract address that generates the random number
     * @param newRandomTool Randoms contract address
     */
    function updateRandomTool(address newRandomTool) external virtual override onlyRole(DEFAULT_ADMIN_ROLE) {
        randomTool = newRandomTool;
    }

    /**
     * @notice Update general fee rate
     * @param newConfigInfo New general fee rate information, including random swap and specific swap
     */
    function updateConfigInfo(ConfigInfo memory newConfigInfo) external virtual override onlyRole(DEFAULT_ADMIN_ROLE) {
        configInfo = newConfigInfo;
    }

    /**
     * @notice Update single NFT fee rate
     * @param nftAddr nft address
     * @param newNftConfigInfo New fee rate information for single NFT
     */
    function updateNftConfigInfo(address nftAddr, ConfigInfo memory newNftConfigInfo) external virtual override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(nftAddr != address(0), "ZERO_ADDRESS");
        if(newNftConfigInfo.randFeeRate == 0 && newNftConfigInfo.noRandFeeRate == 0) {
            enableConfig[nftAddr] = false;
        } else {
            enableConfig[nftAddr] = true;
        }
        _nftConfig[nftAddr] = newNftConfigInfo;
    }

    /**
     * @notice Get fee rate info for Nft
     * @param nftAddr nft contract address
     * @return randFeeRate Random mode fee rate
     * @return noRandFeeRate Specific mode fee rate
     */
    function nftConfigInfo(address nftAddr) public view virtual override returns (uint256 randFeeRate, uint256 noRandFeeRate) {
        if (enableConfig[nftAddr]) {
            randFeeRate = _nftConfig[nftAddr].randFeeRate;
            noRandFeeRate = _nftConfig[nftAddr].noRandFeeRate;
        } else {
            randFeeRate = configInfo.randFeeRate;
            noRandFeeRate = configInfo.noRandFeeRate;
        }
    }

    /**
     * @notice Get fee info for Nft
     * @param nftAddr nft contract address
     * @return randFee Random mode fee
     * @return noRandFee Specific mode fee
     */
    function getFeeInfo(address nftAddr) public view virtual override returns (uint256 randFee, uint256 noRandFee) {
        (uint256 randFeeRate, uint256 noRandFeeRate) = nftConfigInfo(nftAddr);
        randFee = pieceCount.mul(randFeeRate).div(1e18);
        noRandFee = pieceCount.mul(noRandFeeRate).div(1e18);
    }

    /**
     * @notice Set NFT blacklist
     * @param nftAddr nft contract address
     * @param harmful Exclude or not true:in the blacklist, need to exclude false:not in the blacklist
     */
    function setNftBlackList(address nftAddr, bool harmful) external virtual override onlyRole(DEFAULT_ADMIN_ROLE) {
        nftBlackList[nftAddr] = harmful;
    }

    /**
     * @notice Set NFT ID blacklist
     * @param nftAddr nft contract address
     * @param nftId nftId
     * @param harmful Exclude or not true:in the blacklist, need to exclude false:not in the blacklist
     */
    function setNftIdBlackList(address nftAddr, uint256 nftId, bool harmful) external virtual override onlyRole(DEFAULT_ADMIN_ROLE) {
        _setNftIdBlackList(nftAddr, nftId, harmful);
    }

    /**
     * @notice Batch set NFT ID blacklist
     * @param nftAddr nft contract address
     * @param nftIds nftId list
     * @param harmful Exclude or not true:in the blacklist, need to exclude false:not in blacklist
     */
    function batchSetNftIdBlackList(address nftAddr, uint256[] calldata nftIds, bool harmful) external virtual override onlyRole(DEFAULT_ADMIN_ROLE) {
        for(uint i = 0; i < nftIds.length; i++) {
            _setNftIdBlackList(nftAddr, nftIds[i], harmful);
        }
    }

    /**
     * @notice Set NFT ID blacklist
     * @param nftAddr nft contract address
     * @param nftId nftId
     * @param harmful Exclude or not true:in the blacklist, need to exclude false:not in the blacklist
     */
    function _setNftIdBlackList(address nftAddr, uint256 nftId, bool harmful) private {
        nftIdBlackList[nftAddr][nftId] = harmful;
    }

    /**
     * @notice Open ptoken market -> any NFT address can be used to create corresponding ptoken
     * @param newOpenControl true:open, every NFT addresses is allowed  false:close, only whitelisted NFT addresses are allowed
     */
    function setOpenControl(bool newOpenControl) external virtual override onlyRole(DEFAULT_ADMIN_ROLE) {
        openControl = newOpenControl;
    }

    /**
     * @notice Set whitelist for NFT to create ptoken
     * @param nftAddr nft contract address
     * @param isAllow Allow or not true:allow to create false:not allow to create
     */
    function setWhitelist(address nftAddr, bool isAllow) external virtual override onlyRole(DEFAULT_ADMIN_ROLE) {
        _setWhitelist(nftAddr, isAllow);
    }

    /**
     * @notice Batch set whitelist for NFT to create ptoken
     * @param nftAddrs nft contract address
     * @param isAllow Allow or not true:allow to create false:not allow to create
     */
    function batchSetWhitelist(address[] calldata nftAddrs, bool isAllow) external virtual override onlyRole(DEFAULT_ADMIN_ROLE) {
        for(uint i = 0; i < nftAddrs.length; i++) {
            _setWhitelist(nftAddrs[i], isAllow);
        }
    }

    /**
     * @notice Set whitelist for NFT to create ptoken
     * @param nftAddr nft contract address
     * @param isAllow Allow or not true:allow to create false:not allow to create
     */
    function _setWhitelist(address nftAddr, bool isAllow) private {
        require(nftAddr != address(0), "NftController: ZERO_ADDRESS");
        whitelist[nftAddr] = isAllow;
    }

    /**
     * @notice Get randoms from specific range
     * @param nftAddr nft contract address
     * @param rangeMaximum Range of randoms
     * @return uint256 random
     */
    function getRandoms(address nftAddr, uint256 rangeMaximum) external virtual override returns (uint256) {
        return IRandomTool(randomTool).getRandoms(nftAddr, rangeMaximum);
    }

    /**
     * @notice Check if NFT supports opening the ptoken market
     * @param nftAddr nft contract address
     * @return bool bool support ot not true:support false:not support
     */
    function supportedNft(address nftAddr) external view virtual override returns (bool) {
        return openControl ? true : whitelist[nftAddr];
    }

    /**
     * @notice Check if the corresponding operation of NFT Id is supported
     * @param operator Operator
     * @param nftAddr nft contract address
     * @param nftId nftId
     * @param action action
     * @return bool bool support or not true:support false:not support
     */
    function supportedNftId(address operator, address nftAddr, uint256 nftId, Action action) external view virtual override returns (bool) {
        bool check = true;
        if(action == Action.STAKING) {
            check = hasRole(STAKER_ROLE, operator);
        }
        if(check) {
            return _supportedNftId(nftAddr, nftId);
        }
        return false;
    }

    /**
     * @notice Check if the corresponding operation of NFT Id is supported
     * @param nftAddr nft contract address
     * @param nftId nftId
     * @return bool support or not true:support false:not support
     */
    function _supportedNftId(address nftAddr, uint256 nftId) internal view returns (bool) {
        if(nftBlackList[nftAddr]) {
            return false;
        }
        return !nftIdBlackList[nftAddr][nftId];
    }
}
