// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import { Dagon, IAuth } from "../lib/dagon/src/Dagon.sol";

import "../lib/safe-contracts/contracts/common/Enum.sol";
import "../lib/safe-contracts/contracts/common/SignatureDecoder.sol";

import "forge-std/console.sol";

/**
 * TODO
 * - set limits on exchange multiple and check against uint96 casting to dagon token
 * - think about how contributions directly minting voting share can influence the group
 * - provide a better way to value contributions based on updated treasury value
 * -- eg. if I contribute X, then the exchange could be adapted based on the new treasury value
 * - optimise packing on trackedTokens mapping (pack address and exchange rate into uint256)
 */
contract DagonTokenModule {
    /// -----------------------------------------------------------------------
    /// Events & Errors
    /// -----------------------------------------------------------------------

    event AddedSafe(address safe);

    event TrackedTokenSet(address token, uint256 exchange);

    error InstallationFailed();

    error TokenNotTracked();

    error ContributionFailed();

    /// -----------------------------------------------------------------------
    /// DagonTokenModule Storage
    /// -----------------------------------------------------------------------

    Dagon public immutable DAGON_SINGLETON;

    /// @notice Mapping of tokens for which contributions are tracked
    /// - eg. for a safe with WETH => 2, owners are minted 2 x Dagon tokens for every 1 WETH contributed
    mapping(address => mapping(address => uint256)) public safesTrackedTokenExchangeRates;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(address _dagonAddress) {
        DAGON_SINGLETON = Dagon(_dagonAddress);
    }

    /// -----------------------------------------------------------------------
    /// Setup Functions
    /// -----------------------------------------------------------------------

    /**
     * @notice Installs the Dagon token and adds the safe to the list of safes
     * @param owners List of owners for the safe
     * @param setting Settings for the safe
     * @param meta Metadata for the safe
     * todo - restrict if already set
     */
    function install(
        Dagon.Ownership[] memory owners,
        Dagon.Settings memory setting,
        Dagon.Metadata memory meta
    )
        public
    {
        bytes memory installCalldata = abi.encodeWithSelector(Dagon.install.selector, owners, setting, meta);

        if (
            !GnosisSafe(msg.sender).execTransactionFromModule(
                address(DAGON_SINGLETON), 0, installCalldata, Enum.Operation.Call
            )
        ) {
            revert InstallationFailed();
        }

        // Default native token exchange rate to 1
        safesTrackedTokenExchangeRates[msg.sender][address(0)] = 1;
    }

    /**
     * @notice Sets a token so that owners are minted Dagon tokens when they contribute that token
     * @param token Address of the token to be tracked
     * @param exchange Exchange rate for the token
     * @dev To disable a token, set the exchange rate to 0
     */
    function setTrackedToken(address token, uint256 exchange) public {
        emit TrackedTokenSet(token, safesTrackedTokenExchangeRates[msg.sender][token] = exchange);
    }

    /// -----------------------------------------------------------------------
    /// Contribution Functions
    /// -----------------------------------------------------------------------

    /**
     * @notice Tracks owners contribution with Dagon tokens
     * @param standard Token type (where DAGON=0 is taken as native token)
     * todo - add support for non native tokens
     * todo - ensure sender is an owner
     */
    function contribute(address safe, Dagon.Standard standard) public payable {
        // Mint the owner a token representing their contribution based on the type of token contributed
        if (standard == Dagon.Standard.DAGON) {
            bytes memory mintCalldata = abi.encodeWithSelector(
                Dagon.mint.selector, msg.sender, uint96(msg.value * safesTrackedTokenExchangeRates[safe][address(0)])
            );

            if (
                !GnosisSafe(safe).execTransactionFromModule(
                    address(DAGON_SINGLETON), 0, mintCalldata, Enum.Operation.Call
                )
            ) {
                revert ContributionFailed();
            }
            // Forward the contribution to the safe
            safe.call{ value: msg.value }("");
        }
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
