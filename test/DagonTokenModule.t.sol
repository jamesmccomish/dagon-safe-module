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
import { DagonTokenModule } from "../src/DagonTokenModule.sol";

contract DagonTokenModuleTest is BasicTestConfig, SafeTestTools {
    using stdStorage for StdStorage;
    using SafeTestLib for SafeInstance;

    StdStorage private stdstore;
    SafeInstance private safeInstance;

    Safe public safe;
    address public safeAddress;

    Dagon public dagon;
    address public dagonAddress;

    DagonTokenModule public dagonTokenModule;
    address public dagonTokenModuleAddress;

    // Test settings for dagon
    uint96 public constant INITIAL_BALANCE = 1000;
    Dagon.Settings setting;
    Dagon.Metadata meta;

    // Config for safe
    uint256 public constant THRESHOLD = 1;
    uint256 public constant STARTING_BALANCE = 1 ether;

    /// -----------------------------------------------------------------------
    /// Setup
    /// -----------------------------------------------------------------------

    function setUp() public {
        setupDagon();
        setupDagonModule();
        setupSafe();
    }

    function setupDagon() public {
        dagon = new Dagon();
        dagonAddress = address(dagon);
    }

    function setupDagonModule() public {
        dagonTokenModule = new DagonTokenModule(dagonAddress);
        dagonTokenModuleAddress = address(dagonTokenModule);
    }

    function setupSafe() public {
        address[] memory owners = new address[](2);
        owners[0] = alice;
        owners[1] = bob;

        uint256[] memory pks = new uint256[](2);
        pks[0] = alicePk;
        pks[1] = bobPk;

        safeInstance = _setupSafe(pks, THRESHOLD, STARTING_BALANCE);
        safe = safeInstance.safe;
        safeAddress = address(safe);

        safeInstance.enableModule(dagonTokenModuleAddress);
    }

    /// -----------------------------------------------------------------------
    /// Setup tests
    /// -----------------------------------------------------------------------

    function test_setupSafe() public {
        assertEq(safeInstance.threshold, 1);
        assertEq(safeInstance.owners[0], bob);
        assertEq(safeInstance.owners[1], alice);
        assertEq(safeInstance.safe.isModuleEnabled(dagonTokenModuleAddress), true);
    }

    function test_setDagonForSafe() public {
        // Check setting on dagon for safes token fallback handler
        (address setTkn, uint88 setThreshold, Dagon.Standard setStd) = dagon.getSettings(dagonTokenModuleAddress);

        assertEq(address(setTkn), address(setting.token));
        assertEq(uint256(setThreshold), uint256(setting.threshold));
        assertEq(uint8(setStd), uint8(setting.standard));

        // Check metadata on dagon for safes token fallback handler
        (string memory name, string memory symbol, string memory tokenURI, IAuth authority) =
            dagon.getMetadata(dagonTokenModuleAddress);

        assertEq(name, meta.name);
        assertEq(symbol, meta.symbol);
        assertEq(tokenURI, meta.tokenURI);
        assertEq(address(authority), address(meta.authority));
    }

    /// -----------------------------------------------------------------------
    /// Module tests
    /// -----------------------------------------------------------------------

    // function test_install() public {
    //     prank(alice);
    //     dagonTokenModule.contribute(safeAddress, Dagon.Standard.DAGON, { value: 1 ether });
    // }

    // function test_contributeNativeToken() public {
    //     prank(alice);
    //     dagonTokenModule.contribute(safeAddress, Dagon.Standard.DAGON, { value: 1 ether });
    // }
}
