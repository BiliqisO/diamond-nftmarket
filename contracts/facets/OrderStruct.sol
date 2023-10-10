// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct Order {
    uint256 orderId;
    address creator;
    address tokenAddress;
    uint256 tokenId;
    uint256 price;
    bytes signature;
    uint256 deadline;
    bool active;
}
