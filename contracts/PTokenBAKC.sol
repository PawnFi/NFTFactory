// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./PToken.sol";
import "./interfaces/IApeStaking.sol";

/**
 * @title Pawnfi's PTokenBAKC Contract
 * @author Pawnfi
 */
contract PTokenBAKC is PToken {
    using SafeMathUpgradeable for uint256;
    using AddressUpgradeable for address;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;

    // bytes32(uint256(keccak256('eip1967.proxy.stakeDelegate')) - 1))
    bytes32 private constant _STAKE_DELEGATE_SLOT = 0xb8eef20a3eb5434ad680459d96ef6f313aea93fa19e616f4755d155d7b1b3810;

    /**
     * @notice set ApeStaking contract address
     * @param stakeDelegate ApeStaking address
     */
    function setStakeDelegate(address stakeDelegate) public virtual {
        require(IOwnable(factory).owner() == msg.sender, "Caller isn't owner");
        require(
            AddressUpgradeable.isContract(stakeDelegate),
            "PTokenBAKC: stakeDelegate is not a contract"
        );
        bytes32 slot = _STAKE_DELEGATE_SLOT;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            sstore(slot, stakeDelegate)
        }
    }

    /**
     * @notice get ApeStaking contract address
     * @return stakeDelegate ApeStaking address
     */
    function getStakeDelegate() public view virtual returns (address stakeDelegate) {
        bytes32 slot = _STAKE_DELEGATE_SLOT;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            stakeDelegate := sload(slot)
        }
    }

    /**
     * @notice get P-BAYC contract address
     * @return address P-BAYC address
     */
    function getPTokenBAYC() public view virtual returns (address) {
        return IApeStaking(getStakeDelegate()).pbaycAddr();
    }

    /**
     * @notice get P-MAYC contract address
     * @return address P-MAYC address
     */
    function getPTokenMAYC() public view virtual returns (address) {
        return IApeStaking(getStakeDelegate()).pmaycAddr();
    }

    /**
     * @notice get nft id depositor
     * @param nftId nft id
     * @return address nft id depositor address
     */
    function getNftOwner(uint256 nftId) external view virtual returns(address) {
        return _allInfo[nftId].userAddr.isContract() ? _allInfo[nftId].userAddr : address(0);
    }

    /**
     * @notice flash loan nft
     * @param receipient nft receiver and deal loaned nft
     * @param nftIds nft id list
     * @param data calldata
     */
    function flashLoan(address receipient, uint256[] calldata nftIds, bytes memory data) external virtual nonReentrant {
        require(msg.sender == getPTokenBAYC() || msg.sender == getPTokenMAYC(), "Caller is not P-BAYC/P-MAYC address");
        // 1, transfer BAKC to ptokenBAYC or ptokenMAYC
        for (uint256 i = 0; i < nftIds.length; i++) {
            TransferHelper.transferOutNonFungibleToken(IPTokenFactory(factory).nftTransferManager(), nftAddress, address(this), receipient, nftIds[i]);
        }
        
        // 2, use loaned bakc
        IPTokeCall(receipient).pTokenCall(nftIds, data);
        
        // 3, transfer BAKC back from ptokenBAYC or ptokenMAYC
        for (uint256 i = 0; i < nftIds.length; i++) {
            TransferHelper.transferInNonFungibleToken(IPTokenFactory(factory).nftTransferManager(), nftAddress, receipient, address(this), nftIds[i]);
        }
    }

    /**
     * @dev See {PToken-specificTrade}.
     */
    function specificTrade(uint256[] memory nftIds) public virtual override {
        IApeStaking(getStakeDelegate()).onStopStake(msg.sender, nftAddress, nftIds, IApeStaking.RewardAction.ONREDEEM);
        super.specificTrade(nftIds);
    }

    /**
     * @dev See {PToken-withdraw}.
     */
    function withdraw(uint256[] memory nftIds) public virtual override returns (uint256 tokenAmount) {
        IApeStaking(getStakeDelegate()).onStopStake(msg.sender, nftAddress, nftIds, IApeStaking.RewardAction.ONWITHDRAW);
        return super.withdraw(nftIds);
    }

    /**
     * @dev See {PToken-convert}.
     */
    function convert(uint256[] memory nftIds) public virtual override {
        IApeStaking(getStakeDelegate()).onStopStake(msg.sender, nftAddress, nftIds, IApeStaking.RewardAction.ONWITHDRAW);
        super.convert(nftIds);
    }
}

interface IPTokeCall {
    function pTokenCall(uint256[] calldata nftIds, bytes memory data) external;
}