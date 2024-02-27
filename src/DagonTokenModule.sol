// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import { Dagon, IAuth } from "../lib/dagon/src/Dagon.sol";
import { Enum } from "../lib/safe-contracts/contracts/common/Enum.sol";

import "forge-std/console.sol";

/**
 * TODO
 * - set limits on exchange multiple and check against uint96 casting to dagon token
 * - think about how contributions directly minting voting share can influence group voting security
 *      eg. if a user contributes a large amount of a token, they could quickly execute whatever they want
 * - provide a better way to value contributions based on updated treasury value
 *      eg. if I contribute X, then the exchange could be adapted based on the new treasury value
 * - optimise packing on trackedTokens mapping (pack address and exchange rate into uint256)
 * - more efficient decoding using assembly in transfer handlers
 */
contract DagonTokenModule {
    /// -----------------------------------------------------------------------
    /// Events & Errors
    /// -----------------------------------------------------------------------

    event TrackedTokenSet(address token, uint256 exchange);

    error InstallationFailed();
    error InvalidOwner();
    error TokenNotTracked();
    error ContributionFailed();
    error TokenTransferFailed();

    /// -----------------------------------------------------------------------
    /// DagonTokenModule Storage
    /// -----------------------------------------------------------------------

    /// @dev The immutable address of the dagon singleton
    Dagon public immutable DAGON_SINGLETON;

    /// @dev Mapping of tokens for which contributions are tracked
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
     */
    function install(
        Dagon.Ownership[] memory owners,
        Dagon.Settings memory setting,
        Dagon.Metadata memory meta
    )
        public
        payable
    {
        if (DAGON_SINGLETON.totalSupply(uint256(uint160(msg.sender))) != 0) revert InstallationFailed();

        bytes memory installCalldata = abi.encodeWithSelector(Dagon.install.selector, owners, setting, meta);

        if (
            !GnosisSafe(msg.sender).execTransactionFromModule(
                address(DAGON_SINGLETON), 0, installCalldata, Enum.Operation.Call
            )
        ) revert InstallationFailed();

        // Default native token exchange rate to 1
        safesTrackedTokenExchangeRates[msg.sender][address(0)] = 1;
    }

    /**
     * @notice Sets a token so that owners are minted Dagon tokens when they contribute that token
     * @param token Address of the token to be tracked
     * @param exchange Exchange rate for the token
     * @dev To disable a token, set the exchange rate to 0
     */
    function setTrackedToken(address token, uint256 exchange) public payable {
        emit TrackedTokenSet(token, safesTrackedTokenExchangeRates[msg.sender][token] = exchange);
    }

    /// -----------------------------------------------------------------------
    /// Contribution Functions
    /// -----------------------------------------------------------------------

    /**
     * @notice Tracks owners contribution with Dagon tokens
     * @param safe The safe to which the contribution is made
     * @param standard Token type (where DAGON=0 is taken as native token)
     * @param contributionCalldata Calldata for the transfer function of the token
     * @dev contributionCalldata is abi.encodePacked(tokenAddress, tokenTransferCalldata)
     *      where tokenTransferCalldata is the relevant transferFrom or safeTransferFrom calldata
     */
    function contribute(address safe, Dagon.Standard standard, bytes calldata contributionCalldata) public payable {
        // Mint the owner a token representing their contribution based on the type of token contributed
        if (standard == Dagon.Standard.DAGON) _handleNativeContribution(safe);

        if (standard == Dagon.Standard.ERC20) _handleERC20Contribution(safe, contributionCalldata);
    }

    /// -----------------------------------------------------------------------
    /// Utils
    /// -----------------------------------------------------------------------

    /**
     * @notice Handles the contribution of native tokens
     * @param safe The safe to which the contribution is made
     */
    function _handleNativeContribution(address safe) internal {
        if (!GnosisSafe(safe).isOwner(msg.sender)) revert InvalidOwner();

        // Mint the owner a token representing their contribution based on the type of token contributed
        bytes memory mintCalldata = abi.encodeWithSelector(
            Dagon.mint.selector, msg.sender, uint96(msg.value * safesTrackedTokenExchangeRates[safe][address(0)])
        );

        if (!GnosisSafe(safe).execTransactionFromModule(address(DAGON_SINGLETON), 0, mintCalldata, Enum.Operation.Call))
        {
            revert ContributionFailed();
        }

        // Forward the contribution to the safe
        safe.call{ value: msg.value }("");
    }

    /**
     * @notice Handles the contribution of an ERC20 token
     * @param safe The safe to which the contribution is made
     * @param contributionCalldata The combined token and transfer calldata: abi.encodePacked(tokenAddress,
     * tokenTransferCalldata)
     * TODO - tidy this madness using assembly for decoding
     */
    function _handleERC20Contribution(address safe, bytes calldata contributionCalldata) internal {
        (address tokenAddress, bytes memory transferFromCalldata) =
            (address(uint160(bytes20(contributionCalldata[:20]))), contributionCalldata[24:contributionCalldata.length]);

        uint256 exchangeRate = safesTrackedTokenExchangeRates[safe][tokenAddress];

        if (exchangeRate == 0) revert TokenNotTracked();

        // Extract the transfer details from the calldata
        (address from, address to, uint256 amount) = abi.decode(transferFromCalldata, (address, address, uint256));

        if (!GnosisSafe(safe).isOwner(from)) revert InvalidOwner();

        // Transfer the tokens from the sender to the safe
        (bool success, bytes memory returnData) =
            tokenAddress.call(abi.encodePacked(hex"23b872dd", transferFromCalldata));

        if (!success) revert TokenTransferFailed();

        // Mint the owner a token representing their contribution based on the type of token contributed
        bytes memory mintCalldata = abi.encodeWithSelector(Dagon.mint.selector, from, uint96(amount * exchangeRate));

        if (!GnosisSafe(safe).execTransactionFromModule(address(DAGON_SINGLETON), 0, mintCalldata, Enum.Operation.Call))
        {
            revert ContributionFailed();
        }
    }
}

/// @notice Minimal interface for the module to interact with the Safe contract
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

    /// @dev Returns whether an address is an owner of the Safe.
    function isOwner(address owner) external view returns (bool);
}
