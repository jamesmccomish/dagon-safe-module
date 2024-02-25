// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// solhint-disable func-name-mixedcase

// Test imports
import { stdStorage, StdStorage } from "../lib/forge-std/src/Test.sol";
import { BasicTestConfig } from "./config/BasicTestConfig.t.sol";
import "../lib/safe-tools/src/SafeTestTools.sol";

// Lib imports
import { Dagon, IAuth } from "../lib/dagon/src/Dagon.sol";

// Contract imports
import { DagonContributionModule } from "../src/DagonContributionModule.sol";

contract DagonTokenModuleTest is BasicTestConfig, SafeTestTools {
    using stdStorage for StdStorage;
    using SafeTestLib for SafeInstance;

    StdStorage private stdstore;
    SafeInstance private safeInstance;

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
        uint256[] memory pks = new uint256[](2);
        pks[0] = alicePk;
        pks[1] = bobPk;

        safeInstance = _setupSafe(pks, 1);
        safe = safeInstance.safe;
        safeAddress = address(safe);
    }

    function setupDagon() public {
        dagon = new Dagon();
        dagonAddress = address(dagon);
    }

    function setupDagonContributionModule() public {
        dagonContributionModule = new DagonContributionModule();
        dagonContributionModuleAddress = address(dagonContributionModule);

        // write dagon address to dagonContributionModule
        stdstore.target(dagonContributionModuleAddress).sig("DAGON_SINGLETON()").checked_write(dagonAddress);
    }

    function test_setupSafe() public {
        assertEq(safeInstance.threshold, 1, "threshold not set");
        assertEq(safeInstance.owners[0], bob, "owner not set on safe");
        assertEq(safeInstance.owners[1], alice, "owner not set on safe");
    }

    function test_setupContributionModule() public {
        assertEq(dagonContributionModule.DAGON_SINGLETON(), dagonAddress);
    }

    function test_setDagonForSafe() public {
        // build call to set dagon - 'install'

        Dagon.Ownership[] memory owners = new Dagon.Ownership[](0);

        Dagon.Settings memory setting;
        setting.token = safeAddress;
        setting.standard = Dagon.Standard.DAGON;
        setting.threshold = 1;

        Dagon.Metadata memory meta;
        meta.name = "";
        meta.symbol = "";
        meta.tokenURI = "";
        meta.authority = IAuth(address(0));

        bytes memory installCalldata = abi.encodeWithSelector(Dagon.install.selector, owners, setting, meta);

        (uint8 v, bytes32 r, bytes32 s) = safeInstance.signTransaction(
            alicePk,
            dagonContributionModuleAddress,
            0,
            installCalldata,
            Enum.Operation.DelegateCall,
            0,
            0,
            0,
            address(0),
            address(0)
        );

        // use lib to build tx
        safeInstance.execTransaction(
            dagonContributionModuleAddress,
            0,
            installCalldata,
            Enum.Operation.DelegateCall,
            0,
            0,
            0,
            address(0),
            address(0),
            abi.encodePacked(v, r, s)
        );

        (address setTkn, uint88 setThreshold, Dagon.Standard setStd) = dagon.getSettings(safeAddress);
        (,,, IAuth authority) = dagon.getMetadata(safeAddress);

        assertEq(address(setTkn), address(setting.token));
        assertEq(uint256(setThreshold), uint256(setting.threshold));
        assertEq(uint8(setStd), uint8(setting.standard));

        // assertEq(dagon.tokenURI(accountId), "");
        // (,,, IAuth authority) = dagon.getMetadata(address(account));
        // assertEq(address(authority), address(0));
    }
}
