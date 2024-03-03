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
    uint96 public constant INITIAL_DAGON_BALANCE = 1000;
    Dagon.Ownership[] owners;
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

        // Setting our dagon test settings
        owners.push(Dagon.Ownership({ owner: alice, shares: INITIAL_DAGON_BALANCE }));
        owners.push(Dagon.Ownership({ owner: bob, shares: INITIAL_DAGON_BALANCE }));
        setting = Dagon.Settings({ token: address(0), standard: Dagon.Standard.DAGON, threshold: 1 });
        meta = Dagon.Metadata({
            name: "name",
            symbol: "sym",
            tokenURI: "safe.uri",
            authority: IAuth(address(0)),
            totalSupply: 0
        });
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

    /// -----------------------------------------------------------------------
    /// Module setup tests
    /// -----------------------------------------------------------------------

    function test_installDagonForSafe() public {
        vm.prank(safeAddress);
        dagonTokenModule.install(owners, setting, meta);

        // Check setting on dagon for safes token fallback handler
        (address setTkn, uint88 setThreshold, Dagon.Standard setStd) = dagon.getSettings(safeAddress);

        assertEq(address(setTkn), address(setting.token));
        assertEq(uint256(setThreshold), uint256(setting.threshold));
        assertEq(uint8(setStd), uint8(setting.standard));

        // Check metadata on dagon for safes token fallback handler
        (string memory name, string memory symbol, string memory tokenURI, IAuth authority) =
            dagon.getMetadata(safeAddress);

        assertEq(name, meta.name);
        assertEq(symbol, meta.symbol);
        assertEq(tokenURI, meta.tokenURI);
        assertEq(address(authority), address(meta.authority));
    }

    function test_cannotInstallDagonTwice() public {
        vm.prank(safeAddress);
        dagonTokenModule.install(owners, setting, meta);

        vm.expectRevert();
        vm.prank(safeAddress);
        dagonTokenModule.install(owners, setting, meta);
    }

    function test_setTrackedToken() public {
        vm.prank(safeAddress);
        dagonTokenModule.install(owners, setting, meta);

        uint256 exchangeRate = 2;

        vm.prank(safeAddress);
        dagonTokenModule.setTrackedToken(address(mockErc20), exchangeRate);

        assertEq(dagonTokenModule.safesTrackedTokenExchangeRates(safeAddress, address(mockErc20)), exchangeRate);
    }

    /// -----------------------------------------------------------------------
    /// Contribution tests
    /// -----------------------------------------------------------------------

    function test_cannotContributeNativeTokenIfNotOwner() public {
        vm.prank(safeAddress);
        dagonTokenModule.install(owners, setting, meta);

        assertEq(safeAddress.balance, STARTING_BALANCE);
        assertEq(dagon.balanceOf(carl, uint256(uint160(safeAddress))), 0);

        vm.prank(carl);
        vm.expectRevert(DagonTokenModule.InvalidOwner.selector);
        dagonTokenModule.contribute{ value: 1 ether }(safeAddress, Dagon.Standard.DAGON, new bytes(0));

        assertEq(safeAddress.balance, STARTING_BALANCE);
        assertEq(dagon.balanceOf(carl, uint256(uint160(safeAddress))), 0);
    }

    function test_contributeNativeToken() public {
        vm.prank(safeAddress);
        dagonTokenModule.install(owners, setting, meta);

        assertEq(safeAddress.balance, STARTING_BALANCE);
        assertEq(dagon.balanceOf(alice, uint256(uint160(safeAddress))), INITIAL_DAGON_BALANCE);

        vm.prank(alice);
        dagonTokenModule.contribute{ value: 1 ether }(safeAddress, Dagon.Standard.DAGON, new bytes(0));

        assertEq(safeAddress.balance, STARTING_BALANCE + 1 ether);
        assertEq(dagon.balanceOf(alice, uint256(uint160(safeAddress))), INITIAL_DAGON_BALANCE + 1 ether);
    }

    function test_contributeNativeTokenForExchangeRate() public {
        vm.prank(safeAddress);
        dagonTokenModule.install(owners, setting, meta);

        // Update exchange rate for native contributions
        uint256 exchangeRate = 2;
        vm.prank(safeAddress);
        dagonTokenModule.setTrackedToken(address(0), exchangeRate);

        vm.prank(alice);
        dagonTokenModule.contribute{ value: 1 ether }(safeAddress, Dagon.Standard.DAGON, new bytes(0));

        assertEq(safeAddress.balance, STARTING_BALANCE + 1 ether);
        assertEq(
            dagon.balanceOf(alice, uint256(uint160(safeAddress))), INITIAL_DAGON_BALANCE + (exchangeRate * 1 ether)
        );
    }

    function test_cannotContributeErc20IfTokenNotTracked() public {
        vm.prank(safeAddress);
        dagonTokenModule.install(owners, setting, meta);

        // Build the calldata for the contribute function
        bytes memory erc20TransferFromCalldata =
            abi.encodeWithSelector(mockErc20.transferFrom.selector, alice, safeAddress, 1 ether);
        bytes memory contributeCalldata = abi.encodePacked(address(mockErc20), erc20TransferFromCalldata);

        vm.expectRevert(DagonTokenModule.TokenNotTracked.selector);
        vm.prank(alice);
        dagonTokenModule.contribute(safeAddress, Dagon.Standard.ERC20, contributeCalldata);
    }

    function test_cannotContributeErc20IfNotOwner() public {
        vm.prank(safeAddress);
        dagonTokenModule.install(owners, setting, meta);

        mockErc20.mint(carl, 1 ether);

        assertEq(mockErc20.balanceOf(safeAddress), 0);
        assertEq(mockErc20.balanceOf(carl), 1 ether);
        assertEq(dagon.balanceOf(carl, uint256(uint160(safeAddress))), 0);

        vm.prank(carl);
        mockErc20.approve(dagonTokenModuleAddress, 1 ether);

        vm.prank(safeAddress);
        dagonTokenModule.setTrackedToken(address(mockErc20), 1);

        // Build the calldata for the contribute function
        bytes memory erc20TransferFromCalldata =
            abi.encodeWithSelector(mockErc20.transferFrom.selector, carl, safeAddress, 1 ether);
        bytes memory contributeCalldata = abi.encodePacked(address(mockErc20), erc20TransferFromCalldata);

        vm.prank(carl);
        vm.expectRevert(DagonTokenModule.InvalidOwner.selector);
        dagonTokenModule.contribute(safeAddress, Dagon.Standard.ERC20, contributeCalldata);

        assertEq(mockErc20.balanceOf(safeAddress), 0);
        assertEq(mockErc20.balanceOf(carl), 1 ether);
        assertEq(dagon.balanceOf(carl, uint256(uint160(safeAddress))), 0);
    }

    function test_contributeErc20() public {
        vm.prank(safeAddress);
        dagonTokenModule.install(owners, setting, meta);

        mockErc20.mint(alice, 1 ether);

        assertEq(mockErc20.balanceOf(safeAddress), 0);
        assertEq(mockErc20.balanceOf(alice), 1 ether);
        assertEq(dagon.balanceOf(alice, uint256(uint160(safeAddress))), INITIAL_DAGON_BALANCE);

        vm.prank(alice);
        mockErc20.approve(dagonTokenModuleAddress, 1 ether);
        vm.prank(safeAddress);
        dagonTokenModule.setTrackedToken(address(mockErc20), 1);

        // Build the calldata for the contribute function
        bytes memory erc20TransferFromCalldata =
            abi.encodeWithSelector(mockErc20.transferFrom.selector, alice, safeAddress, 1 ether);
        bytes memory contributeCalldata = abi.encodePacked(address(mockErc20), erc20TransferFromCalldata);

        vm.prank(alice);
        dagonTokenModule.contribute(safeAddress, Dagon.Standard.ERC20, contributeCalldata);

        assertEq(mockErc20.balanceOf(safeAddress), 1 ether);
        assertEq(mockErc20.balanceOf(alice), 0);
        assertEq(dagon.balanceOf(alice, uint256(uint160(safeAddress))), INITIAL_DAGON_BALANCE + 1 ether);
    }
}
