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
    ERC721Facet ercFacet;

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
        ercFacet = new ERC721Facet();

        //upgrade diamond with facets

        //build cut struct
        FacetCut[] memory cut = new FacetCut[](3);

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

    function testMint() public {
        ERC721Facet(address(diamond)).mint(address(1));
        assertEq(ERC721Facet(address(diamond)).ownerOf(0), address(1));
    }

    function testName() public {
        ERC721Facet(address(diamond)).mint(address(1));
        assertEq(ERC721Facet(address(diamond)).name(), "BiliNFT");
    }

    function testSymbol() public {
        ERC721Facet(address(diamond)).mint(address(1));
        assertEq(ERC721Facet(address(diamond)).symbol(), "BNFT");
    }

    function testApprove() public {
        ERC721Facet(address(diamond)).mint(address(1));
        vm.prank(address(1));
        ERC721Facet(address(diamond)).setApprovalForAll(
            address(address(2)),
            true
        );
        assertTrue(
            ERC721Facet(address(diamond)).isApprovedForAll(
                address(1),
                address(2)
            )
        );
    }

    function testFailApproval() public {
        ERC721Facet(address(diamond)).mint(address(1));
        vm.prank(address(2));
        ERC721Facet(address(diamond)).setApprovalForAll(
            address(address(1)),
            true
        );
        assertTrue(
            ERC721Facet(address(diamond)).isApprovedForAll(
                address(1),
                address(2)
            )
        );
    }

    function testTransferFrom() public {
        ERC721Facet(address(diamond)).mint(address(1));
        vm.startPrank(address(1));
        ERC721Facet(address(diamond)).setApprovalForAll(
            address(address(this)),
            true
        );
        ERC721Facet(address(diamond)).transferFrom(address(1), address(2), 0);
        assertEq(ERC721Facet(address(diamond)).ownerOf(0), address(2));
        vm.stopPrank();
    }

    function testFailTransferFrom() public {
        ERC721Facet(address(diamond)).mint(address(1));
        vm.startPrank(address(1));
        ERC721Facet(address(diamond)).transferFrom(address(1), address(2), 0);
        assertEq(ERC721Facet(address(diamond)).ownerOf(1), address(1));
        vm.stopPrank();
    }

    function testsafeTransferFrom() public {
        ERC721Facet(address(diamond)).mint(address(1));
        vm.startPrank(address(1));
        ERC721Facet(address(diamond)).setApprovalForAll(
            address(address(this)),
            true
        );
        ERC721Facet(address(diamond)).safeTransferFrom(
            address(1),
            address(2),
            0
        );
        assertEq(ERC721Facet(address(diamond)).ownerOf(0), address(2));
        vm.stopPrank();
    }

    function testFailSafeTransferFrom() public {
        ERC721Facet(address(diamond)).mint(address(1));
        vm.startPrank(address(1));
        ERC721Facet(address(diamond)).setApprovalForAll(
            address(address(1)),
            true
        );
        ERC721Facet(address(diamond)).safeTransferFrom(
            address(1),
            address(0),
            1
        );
        assertEq(ERC721Facet(address(diamond)).ownerOf(1), address(1));
        vm.stopPrank();
    }

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
}
