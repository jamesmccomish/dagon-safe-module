// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { PRBTest } from "../../lib/prb-test/src/PRBTest.sol";
import { console2 } from "../../lib/forge-std/src/console2.sol";

import { AddressTestConfig } from "./AddressTestConfig.t.sol";
import { TokenTestConfig } from "./TokenTestConfig.t.sol";

// Config to setup basic tests
abstract contract BasicTestConfig is PRBTest, AddressTestConfig, TokenTestConfig {
    /// -----------------------------------------------------------------------
    /// Setup
    /// -----------------------------------------------------------------------

    constructor() { }
}
