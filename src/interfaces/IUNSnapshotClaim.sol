// SPDX-LICENSE-IDENTIFIER: GPL-3.0
pragma solidity ^0.8.19;

enum Stake {
    None,
    TierOne,
    TierTwo,
    TierThree,
    TierFour
}

interface IUNSnapshotClaim {
    event Claimed(address indexed account, uint256 indexed streamId, uint128 amount);

    function UN() external view returns (address);

    function sablier() external view returns (address);

    function claimed(uint256, address) external view returns (bool);

    function streamIds(uint256, address) external view returns (uint256);

    function claim(uint256 batch, uint128 amount, Stake stake, bytes32[] calldata proof) external returns (uint256 streamId);

    function withdraw(uint256 batch) external;
}
