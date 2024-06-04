// SPDX-LICENSE-IDENTIFIER: GPL-3.0
pragma solidity ^0.8.19;

import { IUNSnapshotClaim } from "./interfaces/IUNSnapshotClaim.sol";
import { KYCRegistry } from "./KYCRegistry.sol";

import { ISablierV2LockupLinear } from "@sablier/v2-core/src/interfaces/ISablierV2LockupLinear.sol";
import { Broker, LockupLinear } from "@sablier/v2-core/src/types/DataTypes.sol";
import { ud60x18 } from "@sablier/v2-core/src/types/Math.sol";
import { IERC20 } from "@sablier/v2-core/src/types/Tokens.sol";

import { MerkleProofLib } from "solmate/utils/MerkleProofLib.sol";

contract UNSnapshotClaim is IUNSnapshotClaim { // TODO: Potentially add a deadline, add tests and scripts
    using MerkleProofLib for bytes32[];

    address public immutable UN;
    bytes32 public immutable merkleRoot;
    uint40 public immutable cliff;
    uint40 public immutable vestingPeriod;
    address public immutable sablier;
    address public immutable registry;

    mapping(address => bool) public claimed; // TODO: Potentially adopt a bitmap - like in MerkleDistributor
    mapping(address => uint256) public streamIds;

    constructor(address _UN, bytes32 _merkleRoot, uint40 _cliff, uint40 _vestingPeriod, address _sablier, address _registry) {
        UN = _UN;
        merkleRoot = _merkleRoot;
        cliff = _cliff;
        vestingPeriod = _vestingPeriod;
        sablier = _sablier;
        registry = _registry;

        IERC20(UN).approve(address(sablier), type(uint256).max);
    }

    function claim(uint128 amount, bytes32[] calldata proof) external returns (uint256 streamId) {
        require(!claimed[msg.sender], "Already claimed in this snapshot");
        require(KYCRegistry(registry).isKYCVerified(msg.sender), "Not KYC verified");
        require(proof.verify(merkleRoot, keccak256(abi.encode(msg.sender, amount))), "Invalid proof");

        claimed[msg.sender] = true;

        LockupLinear.CreateWithDurations memory params = LockupLinear.CreateWithDurations({
            sender: address(this),
            recipient: msg.sender,
            asset: IERC20(UN),
            totalAmount: amount,
            cancelable: false,
            durations: LockupLinear.Durations({ cliff: cliff, total: vestingPeriod }),
            broker: Broker({ account: address(0), fee: ud60x18(0) })
        });

        streamIds[msg.sender] = streamId = ISablierV2LockupLinear(sablier).createWithDurations(params);

        emit Claimed(msg.sender, streamId, amount);
    }
}