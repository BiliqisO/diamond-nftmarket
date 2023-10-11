// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/Diamond.sol";
import "../contracts/facets/ERC721MarketPlaceFacet.sol";
import "../contracts/facets/ERC721Facet.sol";

import "./helpers/DiamondUtils.sol";

contract DiamondDeployer is DiamondUtils, IDiamondCut {
    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    ERC721MarketplaceFacet erc721MarketPlaceFacet;
    ERC721Facet ercFacet;
    address Creator = address(this);
    bytes Signature;
    address buyer;
    uint buyerKey;

    function setUp() public {
        //deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(
            address(this),
            address(dCutFacet),
            "BiliNFT",
            "BNFT"
        );
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        erc721MarketPlaceFacet = new ERC721MarketplaceFacet();
        ercFacet = new ERC721Facet();

        (address _buyer, uint _buyerKey) = makeAddrAndKey("alice");
        buyer = _buyer;
        buyerKey = _buyerKey;

        //upgrade diamond with facets

        //build cut struct
        FacetCut[] memory cut = new FacetCut[](4);

        cut[0] = (
            FacetCut({
                facetAddress: address(dLoupe),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("DiamondLoupeFacet")
            })
        );

        cut[1] = (
            FacetCut({
                facetAddress: address(ownerF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("OwnershipFacet")
            })
        );
        cut[2] = (
            FacetCut({
                facetAddress: address(erc721MarketPlaceFacet),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("ERC721MarketplaceFacet")
            })
        );
        cut[3] = (
            FacetCut({
                facetAddress: address(ercFacet),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("ERC721Facet")
            })
        );

        //upgrade diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        //call a function
        DiamondLoupeFacet(address(diamond)).facetAddresses();
    }

    function testSignature() public {
        bytes32 ethHash = keccak256(abi.encode(address(ercFacet), 0, 1e18));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(buyerKey, ethHash);
        address signer = ecrecover(ethHash, v, r, s);
        assertEq(signer, buyer);
    }

    function testOwner() public {
        ERC721Facet(address(diamond)).mint(buyer);
        vm.startPrank(buyer);
        bytes32 mHash = keccak256(
            abi.encode(address(ERC721Facet(address(diamond))), 0, 1e18)
        );
        mHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", mHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(buyerKey, mHash);
        Signature = bytes.concat(r, s, bytes1(v));

        ERC721Facet(address(diamond)).setApprovalForAll(
            address(ERC721MarketplaceFacet(address(diamond))),
            true
        );
        ERC721MarketplaceFacet(address(diamond)).createOrder({
            _tokenAddress: address(ERC721Facet(address(diamond))),
            _tokenId: 0,
            _price: 1 ether,
            _signature: bytes(Signature),
            _deadline: block.timestamp + 200
        });

        vm.stopPrank();
    }

    function testFailNotOwner() public {
        (address test, uint testKey) = makeAddrAndKey("add");
        vm.startPrank(test);
        bytes32 mHash = keccak256(
            abi.encode(address(ERC721Facet(address(diamond))), 1, 1e18)
        );
        mHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", mHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(testKey, mHash);
        Signature = bytes.concat(r, s, bytes1(v));
        ERC721Facet(address(diamond)).setApprovalForAll(
            address(ERC721MarketplaceFacet(address(diamond))),
            true
        );
        ERC721MarketplaceFacet(address(diamond)).createOrder({
            _tokenAddress: address(ERC721Facet(address(diamond))),
            _tokenId: 1,
            _price: 1 ether,
            _signature: bytes(Signature),
            _deadline: block.timestamp + 3600
        });
        vm.stopPrank();
    }

    function testApproved() public {
        testOwner();
        address buyerofNFT = makeAddr("buyerofNFT");
        vm.deal(buyerofNFT, 1 ether);
        vm.startPrank(buyerofNFT);
        ERC721Facet(address(diamond)).setApprovalForAll(
            address(ERC721MarketplaceFacet(address(diamond))),
            true
        );
        uint256 initialSellerBalance = buyer.balance;
        ERC721MarketplaceFacet(address(diamond)).executeOrder{value: 1 ether}(
            0
        );
        uint256 finalSellerBalance = buyer.balance;
        assertTrue(
            finalSellerBalance > initialSellerBalance,
            "Seller's balance should increase"
        );
    }

    function testFailPriceCorrect() public {
        testOwner();
        address buyerofNFT = makeAddr("buyerofNFT");
        vm.deal(buyerofNFT, 1 ether);
        vm.startPrank(buyerofNFT);
        ERC721Facet(address(diamond)).setApprovalForAll(
            address(ERC721MarketplaceFacet(address(diamond))),
            true
        );
        uint256 initialSellerBalance = buyer.balance;
        ERC721MarketplaceFacet(address(diamond)).executeOrder{value: 2 ether}(
            1
        );
        uint256 finalSellerBalance = buyer.balance;
        assertFalse(
            finalSellerBalance > initialSellerBalance,
            "Seller's balance should not increase"
        );
    }

    function testFailTimePassed() public {
        testOwner();
        vm.warp(block.timestamp + 250);
        address buyerofNFT = makeAddr("buyerofNFT");
        vm.deal(buyerofNFT, 1 ether);
        vm.startPrank(buyerofNFT);
        ERC721Facet(address(diamond)).setApprovalForAll(
            address(ERC721MarketplaceFacet(address(diamond))),
            true
        );
        ERC721MarketplaceFacet(address(diamond)).executeOrder{value: 1 ether}(
            1
        );
        vm.expectRevert("Order expired");
    }

    function testValidOrder() public {
        testOwner();
        address buyerofNFT = makeAddr("buyerofNFT");
        vm.deal(buyerofNFT, 1 ether);
        vm.startPrank(buyerofNFT);
        ERC721Facet(address(diamond)).setApprovalForAll(
            address(ERC721MarketplaceFacet(address(diamond))),
            true
        );
        ERC721MarketplaceFacet(address(diamond)).executeOrder{value: 1 ether}(
            0
        );
        assertEq(ERC721Facet(address(diamond)).balanceOf(buyerofNFT), 1);
    }

    function testFailInvalidOrder() public {
        testOwner();
        address buyerofNFT = makeAddr("buyerofNFT");
        vm.deal(buyerofNFT, 1 ether);
        vm.startPrank(buyerofNFT);
        ERC721Facet(address(diamond)).setApprovalForAll(
            address(ERC721MarketplaceFacet(address(diamond))),
            true
        );
        ERC721MarketplaceFacet(address(diamond)).executeOrder{value: 1 ether}(
            1
        );
        assertFalse(buyer.balance > 0, "Invalid order");
    }

    function testActiveOrder() public {
        testOwner();
        address buyerofNFT = makeAddr("buyerofNFT");
        vm.deal(buyerofNFT, 2 ether);
        vm.startPrank(buyerofNFT);
        ERC721Facet(address(diamond)).setApprovalForAll(
            address(ERC721MarketplaceFacet(address(diamond))),
            true
        );
        ERC721MarketplaceFacet(address(diamond)).executeOrder{value: 1 ether}(
            0
        );
        assertTrue(buyer.balance > 0, "Order active");
    }

    function testFailInactiveOrder() public {
        testOwner();
        address buyerofNFT = makeAddr("buyerofNFT");
        vm.deal(buyerofNFT, 2 ether);
        vm.startPrank(buyerofNFT);
        ERC721Facet(address(diamond)).setApprovalForAll(
            address(ERC721MarketplaceFacet(address(diamond))),
            true
        );
        ERC721MarketplaceFacet(address(diamond)).executeOrder{value: 1 ether}(
            1
        );
        ERC721MarketplaceFacet(address(diamond)).executeOrder{value: 1 ether}(
            1
        );
        vm.expectRevert("Order inactive");
    }

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
}
