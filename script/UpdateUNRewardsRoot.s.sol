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
        uint256 totalClaimAmount;

        UNRewardsRedemption redemption = UNRewardsRedemption(0x99D8f6CF4dE68ead2392B74e3dD8485E4f74336F);
        bytes32 root;

        redemption.updateRoot(root);
        token.transfer(address(redemption), totalClaimAmount);

        vm.stopBroadcast();
    }
}
