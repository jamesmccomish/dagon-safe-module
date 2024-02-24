// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { BasicTestConfig } from "./config/BasicTestConfig.t.sol";
import { SafeTestConfig, Safe } from "./config/SafeTestConfig.t.sol";

import "forge-std/console.sol";

contract DagonTokenModuleTest is BasicTestConfig, SafeTestConfig {
    Safe safe;
    address safeAddr;

    function setUp() public {
        safeAddr = address(safeProxyFactory.createProxyWithNonce(address(safeSingleton), new bytes(0), uint256(1)));
        safe = Safe(payable(safeAddr));

        address[] memory owners = new address[](1);
        owners[0] = alice;

        // initialize safe with basic owners and threshold
        safe.setup(owners, 1, address(0), new bytes(0), address(0), address(0), 0, payable(address(0)));
    }

    function test_setup() public {
        console.logAddress(address(safe));
    }
}
