// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {Order} from "../facets/OrderStruct.sol";

contract ERC721MarketplaceFacet {
    using ECDSA for bytes32;

    function createOrder(
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _price,
        bytes memory _signature,
        uint256 _deadline
    ) external {
        IERC721 token = IERC721(_tokenAddress);
        require(
            token.ownerOf(_tokenId) == msg.sender,
            "You do not own this token"
        );

        LibDiamond.DiamondStorage storage _order = LibDiamond.diamondStorage();
        Order storage _ds = _order.orders[_order.OrderId];
        _order.OrderId++;
        _ds.orderId = _order.OrderId;
        _ds.creator = msg.sender;
        _ds.tokenAddress = _tokenAddress;
        _ds.tokenId = _tokenId;
        _ds.price = _price;
        _ds.signature = _signature;
        _ds.deadline = _deadline;
        _ds.active = true;
    }

    function executeOrder(uint256 orderId) external payable {
        LibDiamond.DiamondStorage storage _order = LibDiamond.diamondStorage();
        Order storage _ds = _order.orders[orderId];

        // _ds.Order = _ds.orders[_ds.orderId];
        require(_ds.creator != address(0), "Invalid order");
        require(_ds.active, "Order is not active");
        require(msg.value == _ds.price, "Incorrect payment amount");
        require(block.timestamp < _ds.deadline, "Order expired");
        IERC721 token = IERC721(_ds.tokenAddress);
        token.safeTransferFrom(_ds.creator, msg.sender, _ds.tokenId);
        payable(_ds.creator).transfer(_ds.price);
        _ds.active = false;
    }
}
