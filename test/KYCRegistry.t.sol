// SPDX-LICENSE-IDENTIFIER: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/KYCRegistry.sol";

contract KYCRegistryTest is Test {
    KYCRegistry private registry;

    address internal bob;

    function setUp() public {
        registry = new KYCRegistry();

        bob = vm.addr(0xB0B);
    }

    function testRevert_notAuthorizedAdmin() public {
        vm.expectRevert("UNAUTHORIZED");
        vm.prank(bob);
        registry.authorizeAddress(address(bob), true);
    }

    function testRevert_notAuthorizedApproval() public {
        vm.expectRevert("UNAUTHORIZED");
        vm.prank(bob);
        registry.changeKYCStatus(address(bob), true);
    }

    function test_AuthorizeAdmin() external {
        registry.authorizeAddress(address(bob), true);

        vm.prank(bob);
        registry.changeKYCStatus(address(bob), true);

        assertEq(registry.isAuthorizer(address(bob)), true);
        assertEq(registry.isKYCVerified(address(bob)), true);
    }

    function test_changeKYCStatus() external {
        registry.changeKYCStatus(address(bob), true);

        assertEq(registry.isKYCVerified(address(bob)), true);
    }
}
