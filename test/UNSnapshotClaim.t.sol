// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Merkle} from "murky/src/Merkle.sol";

import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {ISablierV2LockupLinear} from "@sablier/v2-core/src/interfaces/ISablierV2LockupLinear.sol";

import {UNSnapshotClaim} from "../src/UNSnapshotClaim.sol";
import {KYCRegistry} from "../src/KYCRegistry.sol";

import {Stake} from "../src/interfaces/IUNSnapshotClaim.sol";

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
        vm.createSelectFork({urlOrAlias: "mainnet"});

        // Setup Addresses
        token = new MockERC20("UN", "UN", 18);
        sablier = ISablierV2LockupLinear(0xAFb979d9afAd1aD27C5eFf4E27226E3AB9e5dCC9); // https://docs.sablier.com/contracts/v2/deployments
        registry = new KYCRegistry();

        // Setup tree
        tree[0] = Claim(address(this), 1e18);
        tree[1] = Claim(address(0xB0B), 1e18);
        tree[2] = Claim(address(0xA17CE), 0);

        // Create proof
        m = new Merkle();

        bytes32[] memory data = new bytes32[](3);
        data[0] = keccak256(bytes.concat(keccak256(abi.encode(tree[0]))));
        data[1] = keccak256(bytes.concat(keccak256(abi.encode(tree[1]))));
        data[2] = keccak256(bytes.concat(keccak256(abi.encode(tree[2]))));

        hashedTree = data;

        root = m.getRoot(data);

        // Deploy Claim Contract
        snapshotClaim = new UNSnapshotClaim(
            address(token), 
            root, 
            uint40(block.timestamp) + 8 days, 
            0, 
            4 days, // Important to note this is the total, which includes the cliff duration
            address(sablier), 
            address(registry)
        );
        token.mint(address(snapshotClaim), 2e18);

        // Add (this) to the KYC registry
        registry.changeKYCStatus(address(this), true);
    }

    function test_ClaimInstant() external {
        uint256 nextStreamId = sablier.nextStreamId();
        uint256 streamId = snapshotClaim.claim(tree[0].amount, Stake.None, m.getProof(hashedTree, 0));

        assertGt(streamId, 0);
        assertEq(streamId, nextStreamId);
        assertEq(snapshotClaim.claimed(address(this)), true);
        assertEq(snapshotClaim.streamIds(address(this)), streamId);

        vm.warp(block.timestamp + 1);
        assertEq(sablier.withdrawableAmountOf(streamId), 1e18);
    }

    function test_ClaimTiered() external {
        uint256 nextStreamId = sablier.nextStreamId();
        uint256 streamId = snapshotClaim.claim(tree[0].amount, Stake.TierOne, m.getProof(hashedTree, 0));

        assertGt(streamId, 0);
        assertEq(streamId, nextStreamId);
        assertEq(snapshotClaim.claimed(address(this)), true);
        assertEq(snapshotClaim.streamIds(address(this)), streamId);

        assertEq(sablier.getEndTime(streamId), block.timestamp + 4 days);
        assertEq(sablier.getDepositedAmount(streamId), 1e18 * 115 / 100); // 15% bonus
    }

    function test_ClaimTier4() external {
        uint256 streamId = snapshotClaim.claim(tree[0].amount, Stake.TierFour, m.getProof(hashedTree, 0));

        assertEq(sablier.getEndTime(streamId), block.timestamp + 16 days); // base (4 days) * 4
        assertEq(sablier.getDepositedAmount(streamId), 1e18 * 1.6353701548); // 0.15 * 1.618^3
    }

    function testRevert_ImproperAmountsShouldRevert() external {
        bytes32[] memory proof = m.getProof(hashedTree, 0);
        vm.expectRevert("Invalid proof");
        snapshotClaim.claim(tree[0].amount + 1, Stake.None, proof);

        vm.expectRevert("Invalid proof");
        snapshotClaim.claim(tree[0].amount - 1, Stake.None, proof);

        vm.expectRevert("Invalid proof");
        snapshotClaim.claim(0, Stake.None, proof);
    }

    function testRevert_AlreadyClaimed() external {
        bytes32[] memory proof = m.getProof(hashedTree, 0);
        snapshotClaim.claim(tree[0].amount, Stake.None, proof);

        vm.expectRevert("Already claimed in this snapshot");
        snapshotClaim.claim(tree[0].amount, Stake.None, proof);
    }

    function testRevert_InvalidProof() external {
        bytes32[] memory proof = m.getProof(hashedTree, 1);
        vm.expectRevert("Invalid proof");
        snapshotClaim.claim(tree[0].amount, Stake.None, proof);
    }

    function testRevert_NotKYCVerified() external {
        bytes32[] memory proof = m.getProof(hashedTree, 1);
        vm.expectRevert("Not KYC verified");
        vm.prank(address(0xB0B));
        snapshotClaim.claim(tree[1].amount, Stake.None, proof);
    }

    function test_SablierStreamWithdraw() external {
        uint256 streamId = snapshotClaim.claim(tree[0].amount, Stake.TierOne, m.getProof(hashedTree, 0));

        uint128 tierOneAmount = tree[0].amount * 115 / 100;

        vm.warp(block.timestamp + 2 days);

        sablier.withdraw(streamId, address(this), 0.5e18);

        assertEq(token.balanceOf(address(this)), 0.5e18);
        assertEq(sablier.streamedAmountOf(streamId), tierOneAmount / 2);
        assertEq(sablier.withdrawableAmountOf(streamId), (tierOneAmount / 2) - 0.5e18);
    }

    function test_SablierStreamWithdrawMax() external {
        uint256 streamId = snapshotClaim.claim(tree[0].amount, Stake.TierOne, m.getProof(hashedTree, 0));

        uint128 tierOneAmount = tree[0].amount * 115 / 100;

        vm.warp(block.timestamp + 2 days);

        sablier.withdrawMax(streamId, address(this));

        assertEq(token.balanceOf(address(this)), tierOneAmount / 2);
        assertEq(sablier.streamedAmountOf(streamId), tierOneAmount / 2);
        assertEq(sablier.withdrawableAmountOf(streamId), 0);
    }

    function test_SablierCliff() external {
        snapshotClaim = new UNSnapshotClaim(
            address(token), 
            root, 
            uint40(block.timestamp) + 8 days, 
            1 days, 
            4 days,
            address(sablier), 
            address(registry)
        );
        token.mint(address(snapshotClaim), 2e18);

        uint256 streamId = snapshotClaim.claim(tree[0].amount, Stake.TierOne, m.getProof(hashedTree, 0));

        uint128 tierOneAmount = tree[0].amount * 115 / 100;

        vm.warp(block.timestamp + 12 hours);
        assertEq(sablier.withdrawableAmountOf(streamId), 0);

        vm.warp(block.timestamp + 12 hours);
        assertEq(sablier.withdrawableAmountOf(streamId), tierOneAmount / 4); // 1/4 will be unlocked at cliff end, as the stream totals 4 days, 1 day would be cliff and 3 would be linearly streamed.

        vm.warp(block.timestamp + 24 hours);
        assertEq(sablier.withdrawableAmountOf(streamId), tierOneAmount / 2); // 1/2 after a day as 2 days have elapsed
    }

    function testRevert_DeadlineMet() external {
        bytes32[] memory proof = m.getProof(hashedTree, 0);
        vm.warp(block.timestamp + 8 days);

        vm.expectRevert("Claim ended");
        snapshotClaim.claim(tree[0].amount, Stake.None, proof);
    }

    function testRevert_DeadlineNotYetMet() external {
        vm.expectRevert("Claim ongoing");
        snapshotClaim.withdraw();

        vm.warp(block.timestamp + 7 days);
        vm.expectRevert("Claim ongoing");
        snapshotClaim.withdraw();
    }

    function testRevert_UnauthorizedWithdraw() external {
        vm.expectRevert("UNAUTHORIZED");
        vm.prank(address(0xB0B));
        snapshotClaim.withdraw();
    }

    function test_WithdrawFunds() external {
        vm.warp(block.timestamp + 8 days + 1);

        snapshotClaim.withdraw();

        assertEq(token.balanceOf(address(this)), 2e18);
        assertEq(token.balanceOf(address(snapshotClaim)), 0);
    }
}

struct Claim {
    address account;
    uint128 amount;
}
