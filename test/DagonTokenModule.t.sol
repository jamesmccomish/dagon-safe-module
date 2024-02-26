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
import { DagonTokenFallbackHandler } from "../src/DagonTokenFallbackHandler.sol";

contract DagonTokenModuleTest is BasicTestConfig, SafeTestTools {
    using stdStorage for StdStorage;
    using SafeTestLib for SafeInstance;

    StdStorage private stdstore;
    SafeInstance private safeInstance;

    Safe public safe;
    address public safeAddress;

    Dagon public dagon;
    address public dagonAddress;

    DagonTokenFallbackHandler public dagonTokenFallbackHandler;
    address public dagonTokenFallbackHandlerAddress;

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
        setupDagonTokenFallbackHandler();
        setupSafe();
    }

    function setupDagon() public {
        dagon = new Dagon();
        dagonAddress = address(dagon);
    }

    function setupDagonTokenFallbackHandler() public {
        Dagon.Ownership[] memory owners = new Dagon.Ownership[](2);
        owners[0] = Dagon.Ownership({ owner: alice, shares: INITIAL_BALANCE });
        owners[1] = Dagon.Ownership({ owner: bob, shares: INITIAL_BALANCE });

        setting = Dagon.Settings({ token: address(0), standard: Dagon.Standard.DAGON, threshold: 1 });

        meta = Dagon.Metadata({
            name: "name",
            symbol: "sym",
            tokenURI: "safe.uri",
            authority: IAuth(address(0)),
            totalSupply: 0
        });

        dagonTokenFallbackHandler = new DagonTokenFallbackHandler(dagonAddress, owners, setting, meta);
        dagonTokenFallbackHandlerAddress = address(dagonTokenFallbackHandler);
    }

    function setupSafe() public {
        address[] memory owners = new address[](2);
        owners[0] = alice;
        owners[1] = bob;

        // Setup a safe with some owners, and the dagon token fallback handler as the fallback handler
        bytes memory init = abi.encodeWithSelector(
            Safe.setup.selector,
            owners,
            THRESHOLD,
            address(0),
            new bytes(0),
            dagonTokenFallbackHandlerAddress,
            address(0),
            0,
            payable(address(0))
        );

        // Format for the safe-tools lib
        AdvancedSafeInitParams memory params;
        params.initData = init;

        uint256[] memory pks = new uint256[](2);
        pks[0] = alicePk;
        pks[1] = bobPk;

        safeInstance = _setupSafe(pks, THRESHOLD, STARTING_BALANCE, params);
        safe = safeInstance.safe;
        safeAddress = address(safe);
    }

    /// -----------------------------------------------------------------------
    /// Setup tests
    /// -----------------------------------------------------------------------

    function test_setupSafe() public {
        assertEq(safeInstance.threshold, 1, "threshold not set");
        assertEq(safeInstance.owners[0], bob, "owner not set on safe");
        assertEq(safeInstance.owners[1], alice, "owner not set on safe");
    }

    function test_setDagonForSafe() public {
        // Check setting on dagon for safes token fallback handler
        (address setTkn, uint88 setThreshold, Dagon.Standard setStd) =
            dagon.getSettings(dagonTokenFallbackHandlerAddress);

        assertEq(address(setTkn), address(setting.token));
        assertEq(uint256(setThreshold), uint256(setting.threshold));
        assertEq(uint8(setStd), uint8(setting.standard));

        // Check metadata on dagon for safes token fallback handler
        (string memory name, string memory symbol, string memory tokenURI, IAuth authority) =
            dagon.getMetadata(dagonTokenFallbackHandlerAddress);

        assertEq(name, meta.name);
        assertEq(symbol, meta.symbol);
        assertEq(tokenURI, meta.tokenURI);
        assertEq(address(authority), address(meta.authority));
    }

    /**
     * TODO
     * - native transfers are not supported since there is a seperate 'receive' fallback on the safe
     */
    // function test_fallbackMint() public {
    //     // Send some eth to the safe to trigger the fallback
    //     safeAddress.call{ value: 1 ether }("");

    //     // Check the balance of the safe
    //     assertEq(asafeAddress.balance, 1 ether);
    // }

    /// -----------------------------------------------------------------------
    /// Token callback tests
    /// -----------------------------------------------------------------------

    function test_mintOnErc1155SafeTransfer() public {
        // Mint alice some erc1155 tokens
        mockErc1155.mint(alice, 1, 1000, "");

        // Send some erc1155 tokens to the safe to trigger the fallback
        vm.prank(alice);
        mockErc1155.safeTransferFrom(alice, safeAddress, 1, 1000, "");

        // Check balances of safe and alice
        assertEq(mockErc1155.balanceOf(safeAddress, 1), 1000);
        assertEq(mockErc1155.balanceOf(alice, 1), 0);
        assertEq(dagon.balanceOf(alice, uint256(uint160(dagonTokenFallbackHandlerAddress))), 1000 + INITIAL_BALANCE);
    }

    function test_mintOnErc1155SafeBatchTransfer() public {
        // Mint alice some erc1155 tokens
        uint256[] memory ids = new uint256[](2);
        ids[0] = 0;
        ids[1] = 1;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1000;
        amounts[1] = 1000;

        mockErc1155.batchMint(alice, ids, amounts, "");

        // Send some erc1155 tokens to the safe to trigger the fallback
        vm.prank(alice);
        mockErc1155.safeBatchTransferFrom(alice, safeAddress, ids, amounts, "");

        // Check balances of safe and alice
        assertEq(mockErc1155.balanceOf(safeAddress, 0), 1000);
        assertEq(mockErc1155.balanceOf(safeAddress, 1), 1000);
        assertEq(mockErc1155.balanceOf(alice, 0), 0);
        assertEq(mockErc1155.balanceOf(alice, 1), 0);
        assertEq(dagon.balanceOf(alice, uint256(uint160(dagonTokenFallbackHandlerAddress))), 2000 + INITIAL_BALANCE);
    }
}
