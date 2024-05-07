// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

abstract contract verifierLogicAbstract {
    function verifyPartial(
        uint256[] memory pubInputs,
        bytes memory proof,
        bool success,
        bytes32[1033] memory transcript
    ) public view virtual returns (bool, bytes32[1033] memory);
}
