// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import { Dagon, IAuth } from "../lib/dagon/src/Dagon.sol";

import "../lib/safe-contracts/contracts/common/Enum.sol";
import "../lib/safe-contracts/contracts/common/SignatureDecoder.sol";

import "forge-std/console.sol";

contract DagonTokenModule {
    /// -----------------------------------------------------------------------
    /// Events & Errors
    /// -----------------------------------------------------------------------

    event AddedSafe(address safe);

    error InstallationFailed();

    error ContributionFailed();

    /// -----------------------------------------------------------------------
    /// DagonTokenModule Storage
    /// -----------------------------------------------------------------------
    Dagon public immutable DAGON_SINGLETON;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(address _dagonAddress) {
        DAGON_SINGLETON = Dagon(_dagonAddress);
    }

    /// -----------------------------------------------------------------------
    /// Public Functions
    /// -----------------------------------------------------------------------

    /**
     * @notice Installs the Dagon token and adds the safe to the list of safes
     * @param safe Address of the safe to be added
     * @param owners List of owners for the safe
     * @param setting Settings for the safe
     * @param meta Metadata for the safe
     * todo - should be called from the safe itself
     */
    function install(
        address safe,
        Dagon.Ownership[] memory owners,
        Dagon.Settings memory setting,
        Dagon.Metadata memory meta
    )
        public
    {
        console.log("DagonTokenModule: install");

        bytes memory installCalldata = abi.encodeWithSelector(Dagon.install.selector, owners, setting, meta);

        if (
            !GnosisSafe(safe).execTransactionFromModule(
                address(DAGON_SINGLETON), 0, installCalldata, Enum.Operation.Call
            )
        ) {
            revert InstallationFailed();
        }
    }

    /**
     * @notice Tracks owners contribution with Dagon tokens
     * @param standard Token type (where DAGON=0 is taken as native token)
     * todo - add support for non native tokens
     * todo - ensure sender is an owner
     */
    function contribute(address safe, Dagon.Standard standard) public payable {
        console.log("DagonTokenModule: contribute");

        // Mint the owner a token representing their contribution based on the type of token contributed
        if (standard == Dagon.Standard.DAGON) {
            bytes memory mintCalldata = abi.encodeWithSelector(Dagon.mint.selector, msg.sender, uint96(msg.value));

            if (
                !GnosisSafe(safe).execTransactionFromModule(
                    address(DAGON_SINGLETON), 0, mintCalldata, Enum.Operation.Call
                )
            ) {
                revert ContributionFailed();
            }
        }

        // Forward the contribution to the safe
        safe.call{ value: msg.value }("");
    }
}

// Minimal interface for the module to interact with the Safe contract
interface GnosisSafe {
    /// @dev Allows a Module to execute a Safe transaction without any further confirmations.
    /// @param to Destination address of module transaction.
    /// @param value Ether value of module transaction.
    /// @param data Data payload of module transaction.
    /// @param operation Operation type of module transaction.
    function execTransactionFromModule(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation
    )
        external
        returns (bool success);
}
