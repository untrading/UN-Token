// SPDX-LICENSE-IDENTIFIER: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/UN.sol";

contract DeployUNToken is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        new UN("UN Token", "UN", 18);

        vm.stopBroadcast();
    }
}
