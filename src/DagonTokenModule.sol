// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import { Dagon, IAuth } from "../lib/dagon/src/Dagon.sol";

/**
 * TODO
 * - set limits on exchange multiple and check against uint96 casting to dagon token
 * - think about how contributions directly minting voting share can influence group voting security
 *      eg. if a user contributes a large amount of a token, they could quickly execute whatever they want
 * - provide a better way to value contributions based on updated treasury value
 *      eg. if I contribute X, then the exchange could be adapted based on the new treasury value
 * - optimise packing on trackedTokens mapping (pack address and exchange rate into uint256)
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
    address public immutable DAGON_SINGLETON;

    /// @dev Mapping of tokens for which contributions are tracked
    /// - eg. for a safe with WETH => 2, owners are minted 2 x Dagon tokens for every 1 WETH contributed
    mapping(address => mapping(address => uint256)) public safesTrackedTokenExchangeRates;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(address _dagonAddress) {
        DAGON_SINGLETON = _dagonAddress;
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
        if (Dagon(DAGON_SINGLETON).totalSupply(uint256(uint160(msg.sender))) != 0) revert InstallationFailed();

        bytes memory installCalldata = abi.encodeWithSelector(Dagon.install.selector, owners, setting, meta);

        if (
            !GnosisSafe(msg.sender).execTransactionFromModule(
                DAGON_SINGLETON, 0, installCalldata, GnosisSafe.Operation.Call
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

        if (standard == Dagon.Standard.ERC20) _handleERC20Contribution(contributionCalldata);
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

        if (!GnosisSafe(safe).execTransactionFromModule(DAGON_SINGLETON, 0, mintCalldata, GnosisSafe.Operation.Call)) {
            revert ContributionFailed();
        }

        // Forward the contribution to the safe
        safe.call{ value: msg.value }("");
    }

    /**
     * @notice Handles the contribution of an ERC20 token via transferFrom
     * @param contributionCalldata The combined token and transfer calldata: abi.encodePacked(tokenAddress,
     * tokenTransferCalldata)
     */
    function _handleERC20Contribution(bytes calldata contributionCalldata) internal {
        address from;
        address to;
        uint256 amount;
        uint256 exchangeRate;

        assembly {
            // Extract the token address & transfer calldata
            let tokenAddress := shr(96, calldataload(contributionCalldata.offset))
            // Set transferCalldata
            let transferCalldata := mload(0x40)
            // Copying 96 bytes from calldata, skipping the first 24 bytes (20 for address & 4 for function selector)
            calldatacopy(transferCalldata, add(contributionCalldata.offset, 0x18), 0xc0)

            // Extract details from the transfer calldata
            from := mload(transferCalldata)
            to := mload(add(transferCalldata, 0x20))
            amount := mload(add(transferCalldata, 0x40))

            // Get the exchange rate from storage mapping
            let memPtr := mload(0x40)
            // safesTrackedTokenExchangeRates[to] in slot keccak256(abi.encode(to, uint256(slot)))
            mstore(memPtr, to)
            mstore(add(memPtr, 0x20), safesTrackedTokenExchangeRates.slot)
            let mappingHash := keccak256(memPtr, 0x40)
            // safesTrackedTokenExchangeRates[to][tokenId] in slot keccak256(abi.encode(tokenAddress,mappingHash))
            mstore(memPtr, tokenAddress)
            mstore(add(memPtr, 0x20), mappingHash)
            let exchangeRateHash := keccak256(memPtr, 0x40)
            exchangeRate := sload(exchangeRateHash)
            // If exchange rate is 0
            if iszero(exchangeRate) {
                // Revert with 'TokenNotTracked' error
                mstore(0x00, 0x63cf4410)
                revert(0x1c, 0x04)
            }

            // Prepare and call `isOwner`
            memPtr := mload(0x40)
            // Function selector: keccak256("isOwner(address)") = 0x2f54bf6e
            mstore(memPtr, hex"2f54bf6e")
            mstore(add(memPtr, 0x04), from)
            // Call `isOwner` and write return data to scratch space, reverting if failed
            if iszero(call(gas(), to, 0, memPtr, 0x40, 0x00, 0x20)) {
                // Revert with  error
                mstore(0x00, 0x11111111)
                revert(0x1c, 0x04)
            }
            // If token sender is not owner
            if iszero(mload(0x00)) {
                // Revert with 'InvalidOwner' error
                mstore(0x00, 0x49e27cff)
                revert(0x1c, 0x04)
            }

            // Prepare and call `transferFrom`
            memPtr := mload(0x40)
            // 0x64 = length of transferFrom calldata + function sig
            mstore(transferCalldata, 0x64)
            calldatacopy(transferCalldata, add(contributionCalldata.offset, 0x14), 0x64)
            // Call `transferFrom` and write return data to scratch space, reverting if failed
            if iszero(call(gas(), tokenAddress, 0, transferCalldata, 0x64, 0x00, 0x20)) {
                // Revert with  error
                mstore(0x00, 0x11111111)
                revert(0x1c, 0x04)
            }
            // If transfer failed
            if iszero(mload(0x00)) {
                // Revert with 'TokenTransferFailed' error
                mstore(0x00, hex"045c4b02")
                revert(0x1c, 0x04)
            }
        }

        // todo convert to assembly
        // Mint the owner a token representing their contribution based on the type of token contributed
        bytes memory mintCalldata = abi.encodeWithSelector(Dagon.mint.selector, from, uint96(amount * exchangeRate));

        if (
            !GnosisSafe(to).execTransactionFromModule(
                address(DAGON_SINGLETON), 0, mintCalldata, GnosisSafe.Operation.Call
            )
        ) {
            revert ContributionFailed();
        }
    }
}

/// @notice Minimal interface for the module to interact with the Safe contract
interface GnosisSafe {
    /// @dev Type of call the Safe will make
    enum Operation {
        Call,
        DelegateCall
    }

    /// @dev Allows a Module to execute a Safe transaction without any further confirmations.
    /// @param to Destination address of module transaction.
    /// @param value Ether value of module transaction.
    /// @param data Data payload of module transaction.
    /// @param operation Operation type of module transaction.
    function execTransactionFromModule(
        address to,
        uint256 value,
        bytes calldata data,
        GnosisSafe.Operation operation
    )
        external
        returns (bool success);

    /// @dev Returns whether an address is an owner of the Safe.
    function isOwner(address owner) external view returns (bool);
}
