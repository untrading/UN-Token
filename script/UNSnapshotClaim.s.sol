// SPDX-LICENSE-IDENTIFIER: GPL-3.0
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/UNSnapshotClaim.sol";
import "../src/UN.sol";

contract DeployUNSnapshotClaim is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        UN token;
        bytes32 merkleRoot;
        
        uint40 deadline;
        uint40 cliff;
        uint40 vestingPeriod;

        address sablier;
        address registry;

        UNSnapshotClaim snapshot = new UNSnapshotClaim(address(token), merkleRoot, deadline, cliff, vestingPeriod, sablier, registry);

        vm.stopBroadcast();
    }
}
