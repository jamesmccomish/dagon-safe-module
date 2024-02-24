// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { BasicTestConfig } from "./config/BasicTestConfig.t.sol";
import { SafeTestConfig, Safe } from "./config/SafeTestConfig.t.sol";

import "forge-std/console.sol";

contract DagonTokenModuleTest is BasicTestConfig, SafeTestConfig {
    Safe safe;
    address safeAddress;

    function setUp() public {
        safeAddress = address(safeProxyFactory.createProxyWithNonce(address(safeSingleton), new bytes(0), uint256(1)));
        safe = Safe(payable(safeAddress));

        address[] memory owners = new address[](2);
        owners[0] = alice;
        owners[1] = bob;

        // initialize safe with basic owners and threshold
        safe.setup(owners, 1, address(0), new bytes(0), address(0), address(0), 0, payable(address(0)));
    }

    function test_setupSafe() public {
        // Check that the account from setup is deployed and data is set on account, and safe
        assertEq(safe.getThreshold(), 1, "threshold not set");
        assertEq(safe.getOwners()[0], alice, "owner not set on safe");
        assertEq(safe.getOwners()[1], bob, "owner not set on safe");

        address[] memory owners = new address[](2);
        owners[0] = alice;
        owners[1] = bob;
        // Can not initialize the same account twice
        vm.expectRevert("GS200");
        safe.setup(owners, 1, address(0), new bytes(0), address(0), address(0), 0, payable(address(0)));
    }
}
