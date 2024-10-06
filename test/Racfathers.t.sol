// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/Racfathers.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "forge-std/console.sol";

contract RacfathersNFTTest is Test {
    RacfathersNFT public nft;
    address public owner = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
    address public user1 = address(2);
    address public user2 = address(3);

    function setUp() public {
        vm.prank(owner);
        nft = new RacfathersNFT();
        vm.deal(owner, 100 ether);
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
    }

    function testInitialState() public {
        assertTrue(nft.paused(), "Contract should be paused initially");
        assertEq(nft.owner(), owner, "Owner should be set correctly");
        assertEq(nft.MAX_SUPPLY(), 1728, "Max supply should be 1728");
        assertEq(nft.MINT_PRICE(), 0.11 ether, "Mint price should be 0.11 ether");
    }

    function testUnpause() public {
        vm.prank(owner);
        nft.unpause();
        assertFalse(nft.paused(), "Contract should be unpaused");
    }

    function testMintNFT() public {
        vm.prank(owner);
        nft.unpause();

        vm.prank(user1);
        nft.mintNFT{value: 0.11 ether}(user1);

        assertEq(nft.balanceOf(user1), 1, "User should have 1 NFT");
        assertEq(nft.ownerOf(1), user1, "User should own token ID 1");
    }

    function testBatchMintNFT() public {
        vm.prank(owner);
        nft.unpause();

        vm.prank(user1);
        nft.batchMintNFT{value: 0.55 ether}(user1, 5);

        assertEq(nft.balanceOf(user1), 5, "User should have 5 NFTs");
        for (uint256 i = 1; i <= 5; i++) {
            assertEq(nft.ownerOf(i), user1, "User should own token ID");
        }
    }

    function testMintNFTWhenPaused() public {
        vm.prank(user1);
        vm.expectRevert("Contract is paused");
        nft.mintNFT{value: 0.11 ether}(user1);
    }

    function testMintNFTInsufficientPayment() public {
        vm.prank(owner);
        nft.unpause();

        vm.prank(user1);
        vm.expectRevert(RacfathersNFT.InsufficientBalance.selector);
        nft.mintNFT{value: 0.10 ether}(user1);
        console.log("after", nft.totalSupply());
    }

function testMintNFTMaxSupply() public {
        vm.startPrank(owner);
        nft.unpause();

        uint256 MAX_SUPPLY = nft.MAX_SUPPLY();
        console.log("MAX_SUPPLY:", MAX_SUPPLY);

       
        nft.batchMintNFTOwner(owner, MAX_SUPPLY - 1);

        uint256 currentSupply = nft.totalSupply();
        console.log("Current total supply:", currentSupply);

        assertEq(currentSupply, MAX_SUPPLY - 1, "Total supply should be MAX_SUPPLY - 1");
        console.log(nft.MAX_SUPPLY());
       
        nft.batchMintNFTOwner(owner, 1);

        currentSupply = nft.totalSupply();
        console.log("Final total supply:", currentSupply);

        assertEq(currentSupply, MAX_SUPPLY, "Total supply should be MAX_SUPPLY");

       
        vm.expectRevert();
        nft.mintNFT{value: 0.11 ether}(owner);
        console.log("after", nft.totalSupply());
        vm.stopPrank();
    }




    function testUpdateMerkleRoots() public {
        bytes32 merkleRoot = keccak256(abi.encodePacked("test"));

        vm.prank(owner);
        nft.updateWeeklyMerkleRoot(merkleRoot);
        assertEq(nft.merkleRoot_Weekly(), merkleRoot, "Weekly merkle root should be updated");

        vm.prank(owner);
        nft.updateMonthlyMerkleRoot(merkleRoot);
        assertEq(nft.merkleRoot_Monthly(), merkleRoot, "Monthly merkle root should be updated");
    }

    function testClaimRewardInvalidProof() public {
        vm.prank(owner);
        nft.unpause();

        vm.prank(user1);
        nft.mintNFT{value: 0.11 ether}(user1);

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = keccak256(abi.encodePacked("testingg"));

        vm.prank(user1);
        vm.expectRevert(RacfathersNFT.InvalidMerkleProof.selector);
        nft.claimWeeklyReward(0, 1 ether, 1, 1, proof);
    }

    function testWithdraw() public {
        vm.prank(owner);
        nft.unpause();

        vm.prank(user1);
        nft.mintNFT{value: 0.11 ether}(user1);

        uint256 initialBalance = owner.balance;
        vm.prank(owner);
        nft.withdraw();

        assertEq(owner.balance, initialBalance + 0.11 ether, "Owner should receive the contract balance");
        assertEq(address(nft).balance, 0, "Contract balance should be 0 after withdrawal");
    }

    function testWithdrawUnauthorized() public {
        vm.prank(owner);
        nft.unpause();

        vm.prank(user1);
        nft.mintNFT{value: 0.11 ether}(user1);

        vm.prank(user2);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user2));
        nft.withdraw();
    }

    function testTokenURI() public {
        vm.prank(owner);
        nft.unpause();

        vm.prank(user1);
        nft.mintNFT{value: 0.11 ether}(user1);

        string memory baseURI = "https://tokenuri.test/";
        vm.prank(owner);
        nft.setBaseURI(baseURI);

        assertEq(nft.tokenURI(1), string(abi.encodePacked(baseURI, "1.json")), "Token URI should be correct");
    }

    function testSeeMinted() public {
        vm.prank(owner);
        nft.unpause();

        vm.prank(user1);
        nft.mintNFT{value: 0.11 ether}(user1);

        vm.prank(user1);
        nft.mintNFT{value: 0.11 ether}(user1);

        assertEq(nft.seeMinted(user1), 2, "User should have minted 2 NFTs");
    }

    function testBatchMintNFTOwner() public {
        vm.prank(owner);
        nft.batchMintNFTOwner(owner, 5);

        assertEq(nft.balanceOf(owner), 5, "Owner should have 5 NFTs");
        for (uint256 i = 1; i <= 5; i++) {
            assertEq(nft.ownerOf(i), owner, "Owner should own token ID");
        }
    }
}