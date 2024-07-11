// SPDX-LICENSE-IDENTIFIER: GPL-3.0
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/UNSnapshotClaim.sol";
import "../src/UN.sol";

contract DeployUNSnapshotClaim is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        UN token = UN(0xa4336dDfE88712e3211384dF631F5AFa38b65Eaf);
        bytes32 merkleRoot = 0xdd4d4d1402289331fa4bcb77dc98fb6fc1422912d9507201e35a02bdf3725014;
        
        uint40 deadline = 1733616000;
        uint40 cliff = 0;
        uint40 vestingPeriod = 7257600;
        uint128 totalAmount;

        address sablier = 0xFDD9d122B451F549f48c4942c6fa6646D849e8C1;
        address registry = 0xB49c774Ffa9981Cf4cAe8D7284b8C1968a6E1Bf1;

        UNSnapshotClaim snapshot = new UNSnapshotClaim(address(token), merkleRoot, deadline, cliff, vestingPeriod, totalAmount, sablier, registry);

        vm.stopBroadcast();
    }
}
