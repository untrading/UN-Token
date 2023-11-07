// SPDX-LICENSE-IDENTIFIER: GPL-3.0
pragma solidity ^0.8.19;

import { ISablierV2LockupLinear } from "@sablier/v2-core/src/interfaces/ISablierV2LockupLinear.sol";
import { Broker, LockupLinear } from "@sablier/v2-core/src/types/DataTypes.sol";
import { ud60x18 } from "@sablier/v2-core/src/types/Math.sol";
import { IERC20 } from "@sablier/v2-core/src/types/Tokens.sol";

contract UNSnapshotClaim {
    IERC20 public immutable UN;

    bytes32 public immutable root;

    uint40 public immutable vestingPeriod;

    ISablierV2LockupLinear public immutable sablier;

    mapping(address => bool) public claimed;
    mapping(address => uint256) public streams;

    constructor(IERC20 _UN, bytes32 _root, uint40 _vestingPeriod, ISablierV2LockupLinear _sablier) {
        UN = _UN;
        root = _root;
        vestingPeriod = _vestingPeriod;
        sablier = _sablier;

        UN.approve(address(sablier), type(uint256).max);
    }

    function claim(uint256 amount, bytes32[] calldata proof) external returns (uint256 streamId) {

    }
}