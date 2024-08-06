// SPDX-LICENSE-IDENTIFIER: GPL-3.0
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/UNRewardsRedemption.sol";
import "../src/UN.sol";

contract DeployUNRewardsRedemption is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        UN token;
        bytes32 merkleRoot;
        
        uint40 cliff;
        uint40 vestingPeriod;

        address sablier;
        address registry;

        UNRewardsRedemption redemption = new UNRewardsRedemption(address(token), merkleRoot, cliff, vestingPeriod, sablier, registry);

        vm.stopBroadcast();
    }
}
