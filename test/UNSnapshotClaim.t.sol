// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import { Merkle } from "murky/src/Merkle.sol";

import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { ISablierV2LockupLinear } from "@sablier/v2-core/src/interfaces/ISablierV2LockupLinear.sol";

import { UNSnapshotClaim } from "../src/UNSnapshotClaim.sol";

contract UNSnapshotClaimTest is Test {
    Merkle private m; // Library

    UNSnapshotClaim private claim;
    MockERC20 private token;
    Claim[3] private tree;
    bytes32[] private hashedTree;
    bytes32 private root;
    ISablierV2LockupLinear private sablier;


    function setUp() external {
        // Fork mainnet
        vm.createSelectFork({ urlOrAlias: "mainnet" });
        
        // Setup Addresses
        token = new MockERC20("UN", "UN", 18);
        sablier = ISablierV2LockupLinear(0xB10daee1FCF62243aE27776D7a92D39dC8740f95); // https://docs.sablier.com/contracts/v2/deployments

        // Setup tree
        tree[0] = Claim(address(this), 1e18);
        tree[1] = Claim(address(0xB0B), 1e18);
        tree[2] = Claim(address(0xA17CE), 0);

        // Create proof
        m = new Merkle();

        bytes32[] memory data = new bytes32[](3);
        data[0] = keccak256(abi.encode(tree[0]));
        data[1] = keccak256(abi.encode(tree[1]));
        data[2] = keccak256(abi.encode(tree[2]));

        hashedTree = data;

        root = m.getRoot(data);

        // Deploy Claim Contract
        claim = new UNSnapshotClaim(address(token), root, 5 days, address(sablier));
        token.mint(address(claim), 2e18);
    }

    function test_Claim() external {
        uint256 nextStreamId = ISablierV2LockupLinear(address(sablier)).nextStreamId();
        uint256 streamId = claim.claim(tree[0].amount, m.getProof(hashedTree, 0));

        assertGt(streamId, 0);
        assertEq(streamId, nextStreamId);
        assertEq(claim.claimed(address(this)), true);
        assertEq(claim.streamIds(address(this)), streamId);
    }

    function testRevert_ImproperAmountsShouldRevert() external {
        vm.expectRevert("Invalid proof");
        claim.claim(tree[0].amount + 1, m.getProof(hashedTree, 0));
    }

    function testRevert_AlreadyClaimed() external {

    }

    function testSablierStreamWithdraw() external {

    }

    function testSablierStreamWithdrawMax() external {

    }
}

struct Claim {
    address account;
    uint128 amount;
}