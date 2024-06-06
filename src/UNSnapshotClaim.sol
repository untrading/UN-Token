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

    address public immutable UN;
    bytes32 public immutable merkleRoot;
    uint40 public immutable deadline; // End time in timestamp

    uint40 public immutable cliff; // in seconds
    uint40 public immutable vestingPeriod; // in seconds

    address public immutable sablier;
    address public immutable registry;

    mapping(address => bool) public claimed; // TODO: Potentially adopt a bitmap - like in MerkleDistributor
    mapping(address => uint256) public streamIds;

    constructor(
        address _UN,
        bytes32 _merkleRoot,
        uint40 _deadline,
        uint40 _cliff,
        uint40 _vestingPeriod,
        address _sablier,
        address _registry
    ) Owned(msg.sender) {
        require(_deadline > block.timestamp && _vestingPeriod > 0, "Invalid params");

        UN = _UN;
        merkleRoot = _merkleRoot;
        deadline = _deadline;
        cliff = _cliff;
        vestingPeriod = _vestingPeriod;
        sablier = _sablier;
        registry = _registry;

        IERC20(UN).approve(address(sablier), type(uint256).max);
    }

    function _getVestingPeriodAndAmount(Stake _stake, uint128 amount) internal view returns (uint40 vp, uint128 amt) {
        if (_stake == Stake.None) {
            return (1, amount); // Minimal claim time
        }

        vp = vestingPeriod * uint8(_stake);
        amt = ud60x18(amount).mul(ud60x18(0.15e18).mul(ud60x18(1.618e18).powu(uint8(_stake) - 1)).add(ud60x18(1e18))).intoUint128(); // amount * ((0.15 * 1.618^(tier)) + 1) //* Clean this up in a future release
    }

    function claim(uint128 amount, Stake stake, bytes32[] calldata proof) external returns (uint256 streamId) {
        require(deadline > block.timestamp, "Claim ended");
        require(!claimed[msg.sender], "Already claimed in this snapshot");
        require(KYCRegistry(registry).isKYCVerified(msg.sender), "Not KYC verified");
        require(proof.verify(merkleRoot, keccak256(abi.encode(msg.sender, amount))), "Invalid proof");

        claimed[msg.sender] = true;

        (uint40 vp, uint128 amt) = _getVestingPeriodAndAmount(stake, amount);

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

        streamIds[msg.sender] = streamId = ISablierV2LockupLinear(sablier).createWithDurations(params);

        emit Claimed(msg.sender, streamId, amount);
    }

    function withdraw() external onlyOwner {
        require(deadline < block.timestamp, "Claim ongoing");

        IERC20(UN).transfer(msg.sender, IERC20(UN).balanceOf(address(this)));
    }
}
