// SPDX-LICENSE-IDENTIFIER: GPL-3.0
pragma solidity ^0.8.19;

import "solmate/auth/Owned.sol";

contract KYCRegistry is Owned {
    event AuthorizerStatus(address authorizee, bool status);
    event KYCStatus(address wallet, bool status);

    mapping(address => bool) public isAuthorizer;

    mapping(address => bool) public isKYCVerified;

    constructor() Owned(msg.sender) {
        isAuthorizer[msg.sender] = true;
    }

    function authorizeAddress(address authorizee, bool status) external onlyOwner {
        isAuthorizer[authorizee] = status;

        emit AuthorizerStatus(authorizee, status);
    }

    function changeKYCStatus(address wallet, bool status) external {
        require(isAuthorizer[msg.sender], "UNAUTHORIZED");

        isKYCVerified[wallet] = status;

        emit KYCStatus(wallet, status);
    }
}