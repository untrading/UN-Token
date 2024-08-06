// SPDX-LICENSE-IDENTIFIER: GPL-3.0
pragma solidity ^0.8.19;

import {IUNRewardsRedemption} from "./interfaces/IUNRewardsRedemption.sol";
import {KYCRegistry} from "./KYCRegistry.sol";
import {Stake} from "../src/interfaces/IUNRewardsRedemption.sol";

import "solmate/auth/Owned.sol";

import {ISablierV2LockupLinear} from "@sablier/v2-core/src/interfaces/ISablierV2LockupLinear.sol";
import {Broker, LockupLinear} from "@sablier/v2-core/src/types/DataTypes.sol";
import {ud60x18} from "@prb/math/src/UD60x18.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MerkleProofLib} from "solmate/utils/MerkleProofLib.sol";

contract UNRewardsRedemption is
    IUNRewardsRedemption,
    Owned
{
    using MerkleProofLib for bytes32[];

    address public immutable UN;
    bytes32 public merkleRoot;

    uint40 public cliff; // in seconds
    uint40 public vestingPeriod; // in seconds

    address public immutable sablier;
    address public immutable registry;

    mapping(address => uint128) public claimedAmount;
    mapping(address => uint256[]) public streamIds;

    constructor(
        address _UN,
        bytes32 _merkleRoot,
        uint40 _cliff,
        uint40 _vestingPeriod,
        address _sablier,
        address _registry
    ) Owned(msg.sender) {
        require(_vestingPeriod > 0, "Invalid params");

        UN = _UN;
        merkleRoot = _merkleRoot;
        cliff = _cliff;
        vestingPeriod = _vestingPeriod;
        sablier = _sablier;
        registry = _registry;

        IERC20(UN).approve(address(sablier), type(uint256).max);
    }

    function getStreamId(address user) external view returns (uint256[] memory) {
        return streamIds[user];
    }

    function _getVestingPeriodAndAmount(Stake _stake, uint128 amount) internal view returns (uint40 vp, uint128 amt) {
        if (_stake == Stake.None) {
            return (1, amount); // Minimal claim time
        }

        vp = vestingPeriod * uint8(_stake);
        amt = ud60x18(amount).mul(ud60x18(0.15e18).mul(ud60x18(1.618e18).powu(uint8(_stake) - 1)).add(ud60x18(1e18))).intoUint128(); // amount * ((0.15 * 1.618^(tier)) + 1) //* Clean this up in a future release
    }

    function claim(uint128 amount, Stake stake, bytes32[] calldata proof) external returns (uint256 streamId) {
        require(claimedAmount[msg.sender] < amount, "Invalid amount");
        require(KYCRegistry(registry).isKYCVerified(msg.sender), "Not KYC verified");
        require(proof.verify(merkleRoot, keccak256(bytes.concat(keccak256(abi.encode(msg.sender, amount))))), "Invalid proof"); // OZ/merkle-tree & murky script

        uint128 claimableAmount = amount - claimedAmount[msg.sender];

        claimedAmount[msg.sender] = amount;

        (uint40 vp, uint128 amt) = _getVestingPeriodAndAmount(stake, claimableAmount);

        LockupLinear.CreateWithDurations memory params = LockupLinear.CreateWithDurations({
            sender: address(this),
            recipient: msg.sender,
            asset: IERC20(UN),
            totalAmount: amt,
            cancelable: false,
            transferable: false,
            durations: LockupLinear.Durations({cliff: cliff, total: vp}),
            broker: Broker({account: address(0), fee: ud60x18(0)})
        });

        streamId = ISablierV2LockupLinear(sablier).createWithDurations(params);

        streamIds[msg.sender].push(streamId);

        emit Claimed(msg.sender, streamId, claimableAmount);
    }

    function updateRoot(bytes32 newMerkleRoot) external onlyOwner {
        merkleRoot = newMerkleRoot;

        IERC20(UN).transfer(msg.sender, IERC20(UN).balanceOf(address(this)));
    }

    function updateVesting(uint40 clf, uint40 vp) external onlyOwner {
        cliff = clf;
        vestingPeriod = vp;
    }
}

