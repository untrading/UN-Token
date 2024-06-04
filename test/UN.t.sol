// SPDX-LICENSE-IDENTIFIER: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/UN.sol";

contract UNTest is Test {
    UN private UNToken;

    address internal bob;

    function setUp() public {
        UNToken = new UN("UN Token", "UN", 18);

        bob = vm.addr(0xB0B);
    }

    function testRevert_notAuthorizedMint() public {
        vm.expectRevert("UNAUTHORIZED");
        vm.prank(bob);
        UNToken.mint(bob, 1e18);
    }

    function testRevert_notAuthorizedBurn() public {
        vm.expectRevert("UNAUTHORIZED");
        vm.prank(bob);
        UNToken.burn(bob, 1e18);
    }
}
