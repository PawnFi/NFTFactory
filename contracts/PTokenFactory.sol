// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interfaces/INftController.sol";
import "./interfaces/IPTokenFactory.sol";
import "./BeaconProxy.sol";

/**
 * @title ptoken factory contract
 * @notice Create and manage ptoken info
 * @author Pawnfi
 */
contract PTokenFactory is IPTokenFactory, OwnableUpgradeable {

    /// @notice ptoken service fee collection address
    address public override feeTo;

    /// @notice The management contract address of the ptoken logic contract, for the ptoken proxy contract to obtain the actual logic contract address
    address public override beacon;

    /// @notice NFT controller contract address
    address public override controller;

    /// @notice NFT transfer manager contract address(support standard and non-standard erc721 transfer)
    address public override nftTransferManager;

    /// @notice Underlying NFT contract address list of created ptoken
    address[] public override allNFTs;

    /// @notice Get underlying NFT contract address from ptoken address <pieceTokenAddr,nftAddr>
    mapping(address => address) public override getNftAddress;

    /// @notice Get corresponding ptoken address from NFT contract address <nftAddr,pieceTokenAddr>
    mapping(address => address) public override getPiece;
    
    /// @notice Emitted when ptoken is created
    event PieceTokenCreated(address token, address pieceToken, uint256 pieceTokenLength);

    /**
     * @notice Initialize contract
     * @param owner_ Owner address
     * @param feeTo_ ptoken service fee collection address
     * @param beacon_ The management contract address of the ptoken logic contract, for the ptoken proxy contract to obtain the actual logic contract address
     * @param controller_ NFT controller contract address
     * @param nftTransferManager_ NFT transfer manager contract address(support standard and non-standard erc721 transfer)
     */
    function initialize(address owner_, address feeTo_, address beacon_, address controller_, address nftTransferManager_) external initializer {
        __Ownable_init();
        transferOwnership(owner_);
        feeTo = feeTo_;
        beacon = beacon_;
        controller = controller_;
        nftTransferManager = nftTransferManager_;
    }

    /**
     * @notice Get amount of NFT collections used to create ptoken
     * @return uint256 amount
     */
    function allNFTsLength() external view virtual override returns (uint256) {
        return allNFTs.length;
    }

    /**
     * @notice The configuration when initializing the ptoken proxy contract
     * @member beacon The address of the management contract for the ptoken logic contract
     * @member data Initialize ptoken operation info
     */
    struct Parameters {
        address beacon;
        bytes data;
    }
    /// @notice The configuration when initializing the ptoken proxy contract
    Parameters public override parameters;

    /**
     * @notice Create ptoken
     * @param nftAddr nft contract address
     * @return pieceTokenAddr ptoken contract address
     */
    function createPiece(address nftAddr) public virtual override returns (address pieceTokenAddr) {
        require(nftAddr != address(0) && getPiece[nftAddr] == address(0), 'TOKEN_EXISTS');
        require(INftController(controller).supportedNft(nftAddr), 'FORBIDDEN');//check whitelist

        // abi.encodeWithSelector(bytes4(keccak256("initialize(address)")), nftAddr)
        parameters = Parameters({beacon: beacon, data: abi.encodeWithSelector(0xc4d66de8, nftAddr)});

        pieceTokenAddr = address(new BeaconProxy{salt: keccak256(abi.encode(nftAddr))}());

        delete parameters;

        getPiece[nftAddr] = pieceTokenAddr;
        getNftAddress[pieceTokenAddr] = nftAddr;
        allNFTs.push(nftAddr);
        emit PieceTokenCreated(nftAddr, pieceTokenAddr, allNFTs.length);
    }

    /**
     * @notice Set service fee collection address
     * @param newFeeTo New fee collection address
     */
    function setFeeTo(address newFeeTo) external virtual override onlyOwner {
        feeTo = newFeeTo;
    }

}