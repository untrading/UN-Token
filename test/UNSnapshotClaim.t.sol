// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import { Merkle } from "murky/src/Merkle.sol";

import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { ISablierV2LockupLinear } from "@sablier/v2-core/src/interfaces/ISablierV2LockupLinear.sol";

import { UNSnapshotClaim } from "../src/UNSnapshotClaim.sol";
import { KYCRegistry } from "../src/KYCRegistry.sol";

contract UNSnapshotClaimTest is Test {
    Merkle private m; // Library

    UNSnapshotClaim private snapshotClaim;
    MockERC20 private token;
    Claim[3] private tree;
    bytes32[] private hashedTree;
    bytes32 private root;
    ISablierV2LockupLinear private sablier;
    KYCRegistry private registry;

    function setUp() external {
        // Fork mainnet
        vm.createSelectFork({ urlOrAlias: "mainnet" });
        
        // Setup Addresses
        token = new MockERC20("UN", "UN", 18);
        sablier = ISablierV2LockupLinear(0xB10daee1FCF62243aE27776D7a92D39dC8740f95); // https://docs.sablier.com/contracts/v2/deployments
        registry = new KYCRegistry();

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
        snapshotClaim = new UNSnapshotClaim(address(token), root, 5 days, address(sablier), address(registry));
        token.mint(address(snapshotClaim), 2e18);

        // Add (this) to the KYC registry
        registry.changeKYCStatus(address(this), true);
    }

    function test_Claim() external {
        uint256 nextStreamId = ISablierV2LockupLinear(address(sablier)).nextStreamId();
        uint256 streamId = snapshotClaim.claim(tree[0].amount, m.getProof(hashedTree, 0));

        assertGt(streamId, 0);
        assertEq(streamId, nextStreamId);
        assertEq(snapshotClaim.claimed(address(this)), true);
        assertEq(snapshotClaim.streamIds(address(this)), streamId);
    }

    function testRevert_ImproperAmountsShouldRevert() external {
        bytes32[] memory proof = m.getProof(hashedTree, 0);
        vm.expectRevert("Invalid proof");
        snapshotClaim.claim(tree[0].amount + 1, proof);

        vm.expectRevert("Invalid proof");
        snapshotClaim.claim(tree[0].amount - 1, proof);

        vm.expectRevert("Invalid proof");
        snapshotClaim.claim(0, proof);
    }

    function testRevert_AlreadyClaimed() external {
        bytes32[] memory proof = m.getProof(hashedTree, 0);
        snapshotClaim.claim(tree[0].amount, proof);

        vm.expectRevert("Already claimed in this snapshot");
        snapshotClaim.claim(tree[0].amount, proof);
    }

    function testRevert_InvalidProof() external {
        bytes32[] memory proof = m.getProof(hashedTree, 1);
        vm.expectRevert("Invalid proof");
        snapshotClaim.claim(tree[0].amount, proof);
    }

    function testRevert_NotKYCVerified() external {
        bytes32[] memory proof = m.getProof(hashedTree, 1);
        vm.expectRevert("Not KYC verified");
        vm.prank(address(0xB0B));
        snapshotClaim.claim(tree[1].amount, proof);
    }

    function test_SablierStreamWithdraw() external {

    }

    function test_SablierStreamWithdrawMax() external {

    }
}

struct Claim {
    address account;
    uint128 amount;
}