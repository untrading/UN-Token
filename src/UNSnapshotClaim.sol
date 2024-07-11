// SPDX-LICENSE-IDENTIFIER: GPL-3.0
pragma solidity ^0.8.19;

import {IUNSnapshotClaim} from "./interfaces/IUNSnapshotClaim.sol";
import {KYCRegistry} from "./KYCRegistry.sol";
import {Stake} from "../src/interfaces/IUNSnapshotClaim.sol";

import "solmate/auth/Owned.sol";

import {ISablierV2LockupLinear} from "@sablier/v2-core/src/interfaces/ISablierV2LockupLinear.sol";
import {Broker, LockupLinear} from "@sablier/v2-core/src/types/DataTypes.sol";
import {ud60x18} from "@prb/math/src/UD60x18.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MerkleProofLib} from "solmate/utils/MerkleProofLib.sol";

contract UNSnapshotClaim is
    IUNSnapshotClaim,
    Owned
{
    using MerkleProofLib for bytes32[];

    struct Batch {
        bytes32 merkleRoot;
        uint40 deadline; // End time in timestamp
        uint40 cliff; // in seconds
        uint40 vestingPeriod; // in seconds

        uint128 claimedAmount;
        uint128 totalAmount; // amount funded in this batch with the max mulitplier/stake reward accounted for
    }

    address public immutable UN;

    uint256 public batchIds;
    mapping(uint256 => Batch) public batches;

    address public immutable sablier;
    address public immutable registry;

    mapping(uint256 => mapping(address => bool)) public claimed; // TODO: Potentially adopt a bitmap - like in MerkleDistributor
    mapping(uint256 => mapping(address => uint256)) public streamIds;

    constructor(
        address _UN,
        bytes32 _merkleRoot,
        uint40 _deadline,
        uint40 _cliff,
        uint40 _vestingPeriod,
        uint128 _totalAmount,
        address _sablier,
        address _registry
    ) Owned(msg.sender) {
        require(_deadline > block.timestamp && _vestingPeriod > 0, "Invalid params");

        UN = _UN;

        batchIds += 1;
        batches[batchIds] = Batch(_merkleRoot, _deadline, _cliff, _vestingPeriod, 0, _totalAmount); // could also use _getVesitngPeriodAndAmount with max stake tier to calculate the totalAmount, and then passing in the normal max amount not accounting for stake tiers.
        
        sablier = _sablier;
        registry = _registry;

        IERC20(UN).approve(address(sablier), type(uint256).max);
    }

    function _getVestingPeriodAndAmount(uint256 _batch, Stake _stake, uint128 _amount) internal view returns (uint40 vp, uint128 amt) {
        if (_stake == Stake.None) {
            return (1, _amount); // Minimal claim time
        }

        vp = batches[_batch].vestingPeriod * uint8(_stake);
        amt = ud60x18(_amount).mul(ud60x18(0.15e18).mul(ud60x18(1.618e18).powu(uint8(_stake) - 1)).add(ud60x18(1e18))).intoUint128(); // amount * ((0.15 * 1.618^(tier)) + 1) //* Clean this up in a future release
    }

    function claim(uint256 batch, uint128 amount, Stake stake, bytes32[] calldata proof) external returns (uint256 streamId) {
        require(batches[batch].deadline > block.timestamp, "Claim ended or invalid batch");
        require(!claimed[batch][msg.sender], "Already claimed in this snapshot");
        require(KYCRegistry(registry).isKYCVerified(msg.sender), "Not KYC verified");
        require(proof.verify(batches[batch].merkleRoot, keccak256(bytes.concat(keccak256(abi.encode(msg.sender, amount))))), "Invalid proof"); // OZ/merkle-tree & murky script

        claimed[batch][msg.sender] = true;

        (uint40 vp, uint128 amt) = _getVestingPeriodAndAmount(batch, stake, amount);
        require(batches[batch].claimedAmount + amt <= batches[batch].totalAmount, "exceeds total"); // in case the totalAmount has been miscalculated

        LockupLinear.CreateWithDurations memory params = LockupLinear.CreateWithDurations({
            sender: address(this),
            recipient: msg.sender,
            asset: IERC20(UN),
            totalAmount: amt,
            cancelable: false,
            transferable: false,
            durations: LockupLinear.Durations({cliff: batches[batch].cliff, total: vp}),
            broker: Broker({account: address(0), fee: ud60x18(0)})
        });

        batches[batch].claimedAmount += amt;

        streamIds[batch][msg.sender] = streamId = ISablierV2LockupLinear(sablier).createWithDurations(params);

        emit Claimed(msg.sender, streamId, amount);
    }

    function createNewBatch(bytes32 merkleRoot, uint40 deadline, uint40 cliff, uint40 vestingPeriod, uint128 totalAmount) external onlyOwner returns(uint256 newBatchId) {
        batchIds += 1;
        batches[batchIds] = Batch(merkleRoot, deadline, cliff, vestingPeriod, 0, totalAmount);

        newBatchId = batchIds;
    }

    function withdraw(uint256 batch) external onlyOwner {
        require(batch <= batchIds, "Invalid batch");
        require(batches[batch].deadline < block.timestamp, "Claim ongoing");

        IERC20(UN).transfer(msg.sender, batches[batch].totalAmount - batches[batch].claimedAmount);
    }
}
