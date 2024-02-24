// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// solhint-disable func-name-mixedcase

// Test imports
import { stdStorage, StdStorage } from "../lib/forge-std/src/Test.sol";
import { BasicTestConfig } from "./config/BasicTestConfig.t.sol";
import { SafeTestConfig, Safe } from "./config/SafeTestConfig.t.sol";

// Lib imports
import { Dagon } from "../lib/dagon/src/Dagon.sol";

// Contract imports
import { DagonContributionModule } from "../src/DagonContributionModule.sol";

contract DagonTokenModuleTest is BasicTestConfig, SafeTestConfig {
    using stdStorage for StdStorage;

    StdStorage private stdstore;

    Safe public safe;
    address public safeAddress;

    Dagon public dagon;
    address public dagonAddress;

    DagonContributionModule public dagonContributionModule;
    address public dagonContributionModuleAddress;

    function setUp() public {
        setupSafe();
        setupDagon();
        setupDagonContributionModule();
    }

    function setupSafe() public {
        safeAddress = address(safeProxyFactory.createProxyWithNonce(address(safeSingleton), new bytes(0), uint256(1)));
        safe = Safe(payable(safeAddress));

        address[] memory owners = new address[](2);
        owners[0] = alice;
        owners[1] = bob;

        // initialize safe with basic owners and threshold
        safe.setup(owners, 1, address(0), new bytes(0), address(0), address(0), 0, payable(address(0)));
    }

    function setupDagon() public {
        dagon = new Dagon();
        dagonAddress = address(dagon);
    }

    function setupDagonContributionModule() public {
        dagonContributionModule = new DagonContributionModule();
        dagonContributionModuleAddress = address(dagonContributionModule);

        // write to address in dagon
        stdstore.target(dagonContributionModuleAddress).sig("DAGON_SINGLETON()").checked_write(dagonAddress);
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

    function test_setupContributionModule() public {
        assertEq(dagonContributionModule.DAGON_SINGLETON(), dagonAddress);
    }
}
