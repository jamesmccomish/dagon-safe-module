// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import { Dagon, IAuth } from "../lib/dagon/src/Dagon.sol";

import "../lib/safe-contracts/contracts/interfaces/ERC1155TokenReceiver.sol";
import "../lib/safe-contracts/contracts/interfaces/ERC721TokenReceiver.sol";
import "../lib/safe-contracts/contracts/interfaces/ERC777TokensRecipient.sol";
import "../lib/safe-contracts/contracts/interfaces/IERC165.sol";

import "forge-std/console.sol";

/**
 * @dev
 * !!! In this end this model is not useful !!!
 * It relies on one of the token callbacks to be called, which is not guaranteed
 * Because Safes have a NativeCurrencyPaymentFallback, adapting it to cover native transfers would be difficult
 */
contract DagonTokenFallbackHandler is ERC1155TokenReceiver, ERC777TokensRecipient, ERC721TokenReceiver, IERC165 {
    Dagon public immutable DAGON_SINGLETON;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(
        address _dagonAddress,
        Dagon.Ownership[] memory owners,
        Dagon.Settings memory setting,
        Dagon.Metadata memory meta
    ) {
        DAGON_SINGLETON = Dagon(_dagonAddress);

        DAGON_SINGLETON.install(owners, setting, meta);
    }

    /// -----------------------------------------------------------------------
    /// Token Callbacks
    /// -----------------------------------------------------------------------

    /**
     * @notice Handles ERC1155 Token callback.
     * return Standardized onERC1155Received return value.
     */
    function onERC1155Received(
        address,
        address from,
        uint256 id,
        uint256 amount,
        bytes calldata
    )
        external
        override
        returns (bytes4)
    {
        DAGON_SINGLETON.mint(from, uint96(amount));
        return 0xf23a6e61;
    }

    /**
     * @notice Handles ERC1155 Token batch callback.
     * return Standardized onERC1155BatchReceived return value.
     */
    function onERC1155BatchReceived(
        address,
        address from,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata
    )
        external
        override
        returns (bytes4)
    {
        uint256 totalAmount;
        for (uint256 i; i < ids.length; i++) {
            totalAmount += amounts[i];
        }
        DAGON_SINGLETON.mint(from, uint96(totalAmount));
        return 0xbc197c81;
    }

    /**
     * @notice Handles ERC721 Token callback.
     *  return Standardized onERC721Received return value.
     */
    function onERC721Received(address, address from, uint256, bytes calldata) external override returns (bytes4) {
        DAGON_SINGLETON.mint(from, 1);
        return 0x150b7a02;
    }

    /**
     * @notice Handles ERC777 Token callback.
     * return nothing (not standardized)
     */
    function tokensReceived(address, address, address, uint256, bytes calldata, bytes calldata) external override {
        // We implement this for completeness, doesn't really have any value
    }

    /**
     * @notice Implements ERC165 interface support for ERC1155TokenReceiver, ERC721TokenReceiver and IERC165.
     * @param interfaceId Id of the interface.
     * @return if the interface is supported.
     */
    function supportsInterface(bytes4 interfaceId) external view virtual override returns (bool) {
        return interfaceId == type(ERC1155TokenReceiver).interfaceId
            || interfaceId == type(ERC721TokenReceiver).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    receive() external payable {
        console.log("fallback received");
        console.log(msg.value);
    }
}
