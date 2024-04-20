// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

library Oracle {
    uint256 public constant count = 65535;

    // An observation is a slot that stores a recorded price
    // A pool contract can store up to 65,535 observations
    struct Observation {
        uint32 timestemp;
        int56 tickAccumulated;
        bool initialized;
    }

}