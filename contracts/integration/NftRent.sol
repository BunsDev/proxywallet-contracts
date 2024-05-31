//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../interfaces/ISmartWalletFactory.sol";
import "../interfaces/IAutoExecuteCallback.sol";
import "../interfaces/ISmartWallet.sol";

contract NftRent is ERC721Holder, IAutoExecuteCallback {
    using Address for address;

    struct NftRentInfo {
        address renter;
        uint256 rentEndsAt;
        bytes32 listId;
        bool closed;
    }

    struct NftListInfo {
        address owner;
        address tokenContract;
        uint256 tokenId;
        uint256 rentDuration;
        uint256 ethFee;
        bool fulfilled;
    }

    event List(bytes32 indexed listId);
    event Rent(bytes32 indexed listId, bytes32 indexed rentId);
    event RentReturn(bytes32 indexed rentId);
    event RentReturnForced(bytes32 indexed rentId);

    address immutable smartWalletFactory;

    bytes4[5] public blacklistedFunctionsERC721 = [
        bytes4(0xa22cb465), // setApprovalForAll
        bytes4(0x095ea7b3), // approve
        bytes4(0x23b872dd), // transferFrom
        bytes4(0x42842e0e), // safeTransferFrom(address,address,uint256)
        bytes4(0xb88d4fde) // safeTransferFrom(address,address,uint256,bytes)
    ];

    mapping(bytes32 => NftListInfo) public listInfos;
    mapping(bytes32 => NftRentInfo) public rentInfos;
    uint256 public counter;

    constructor(address _smartWalletFactory) {
        smartWalletFactory = _smartWalletFactory;
    }

    function list(
        address tokenContract,
        uint256 tokenId,
        uint256 rentDuration,
        uint256 ethFee
    ) external returns (bytes32 id) {
        require(rentDuration > 0, "NR: invalid duration");

        IERC721(tokenContract).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId
        );

        id = keccak256(abi.encodePacked(counter++));

        listInfos[id] = NftListInfo({
            owner: msg.sender,
            rentDuration: rentDuration,
            ethFee: ethFee,
            tokenId: tokenId,
            tokenContract: tokenContract,
            fulfilled: false
        });

        emit List(id);
    }

    function rentExternal(bytes32 id) external payable {
        _rent(id, msg.sender);
    }

    function rent(bytes32 id) external payable returns (address smartWallet) {
        bytes32 walletSalt = keccak256(abi.encodePacked(msg.sender, id));
        smartWallet = ISmartWalletFactory(smartWalletFactory).create2Wallet(
            msg.sender,
            address(this),
            walletSalt
        );
        ISmartWallet(smartWallet).addToAllowlist(address(this));
        _rent(id, smartWallet);
    }

    function returnRented(bytes32 rentId) external {
        require(
            ISmartWalletFactory(smartWalletFactory).validateWallet(msg.sender),
            "NR: not a smart wallet"
        );
        NftRentInfo storage rentInfo = rentInfos[rentId];
        require(!rentInfo.closed, "NR: already closed");
        NftListInfo memory listInfo = listInfos[rentInfo.listId];

        IERC721(listInfo.tokenContract).safeTransferFrom(
            msg.sender,
            listInfo.owner,
            listInfo.tokenId
        );

        rentInfo.closed = true;

        ISmartWallet(msg.sender).removeAutoExecute(rentId);
        _resetSmartWallet(listInfo, msg.sender);

        emit RentReturn(rentId);
    }

    function _rent(bytes32 id, address smartWallet) internal {
        require(
            ISmartWalletFactory(smartWalletFactory).validateWallet(smartWallet),
            "NR: not a smart wallet"
        );
        NftListInfo memory listInfo = listInfos[id];

        require(msg.value >= listInfo.ethFee, "NR: Insufficient fee");
        require(!listInfo.fulfilled, "NR: Already fulfilled");

        listInfo.fulfilled = true;

        Address.sendValue(payable(listInfo.owner), listInfo.ethFee);

        // send the rest of eth to smart wallet
        Address.sendValue(payable(smartWallet), msg.value - listInfo.ethFee);

        IERC721(listInfo.tokenContract).safeTransferFrom(
            address(this),
            smartWallet,
            listInfo.tokenId
        );

        uint256 rentEndsAt = block.timestamp + listInfo.rentDuration;
        bytes32 rentId = _configureSmartWallet(
            listInfo,
            id,
            rentEndsAt,
            smartWallet
        );

        listInfos[id] = listInfo;
        rentInfos[rentId] = NftRentInfo({
            renter: smartWallet,
            closed: false,
            rentEndsAt: rentEndsAt,
            listId: id
        });

        emit Rent(id, rentId);
    }

    function autoExecuteCallback(bytes32 rentId) external {
        require(
            ISmartWalletFactory(smartWalletFactory).validateWallet(msg.sender),
            "NR: sender not a smart wallet"
        );
        NftRentInfo storage rentInfo = rentInfos[rentId];
        require(!rentInfo.closed, "NR: already closed");
        require(msg.sender == rentInfo.renter, "NR: invalid sender");
        require(block.timestamp > rentInfo.rentEndsAt, "NR: is not expired");
        rentInfo.closed = true;

        _resetSmartWallet(listInfos[rentInfo.listId], rentInfo.renter);

        emit RentReturnForced(rentId);
    }

    function _configureSmartWallet(
        NftListInfo memory listInfo,
        bytes32 listId,
        uint256 rentEndsAt,
        address smartWallet
    ) private returns (bytes32) {
        ISmartWallet _smartWallet = ISmartWallet(smartWallet);

        for (uint i; i < blacklistedFunctionsERC721.length; i++) {
            bytes4 selector = blacklistedFunctionsERC721[i];
            _smartWallet.blacklist(listInfo.tokenContract, selector);
        }

        return
            _smartWallet.addToAutoExecute(
                listId,
                address(this),
                abi.encodeWithSelector(
                    bytes4(0x42842e0e), // safeTransferFrom(address,address,uint256)
                    smartWallet, // from
                    listInfo.owner, // to
                    listInfo.tokenId // tokenId
                ),
                listInfo.tokenContract,
                0,
                rentEndsAt
            );
    }

    function _resetSmartWallet(
        NftListInfo memory listInfo,
        address smartWallet
    ) private {
        ISmartWallet _smartWallet = ISmartWallet(smartWallet);

        for (uint i; i < blacklistedFunctionsERC721.length; i++) {
            bytes4 selector = blacklistedFunctionsERC721[i];
            _smartWallet.removeFromBlacklist(listInfo.tokenContract, selector);
        }
        _smartWallet.removeFromAllowlist(address(this));
    }
}
