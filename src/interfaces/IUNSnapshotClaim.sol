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

    function merkleRoot() external view returns (bytes32);

    function vestingPeriod() external view returns (uint40);

    function sablier() external view returns (address);

    function claimed(address) external view returns (bool);

    function streamIds(address) external view returns (uint256);

    function claim(uint128 amount, Stake stake, bytes32[] calldata proof) external returns (uint256 streamId);

    function withdraw() external;
}
