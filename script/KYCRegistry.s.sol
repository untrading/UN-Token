// SPDX-LICENSE-IDENTIFIER: GPL-3.0
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/KYCRegistry.sol";

contract DeployRegistry is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        KYCRegistry registry = new KYCRegistry();

        // registry.authorizeAddress(0x..., true);

        vm.stopBroadcast();
    }
}
