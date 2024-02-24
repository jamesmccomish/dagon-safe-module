// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// Gnosis Safe imports
import { Safe, Enum } from "../../lib/safe-contracts/contracts/Safe.sol";
import { CompatibilityFallbackHandler } from
    "../../lib/safe-contracts/contracts/handler/CompatibilityFallbackHandler.sol";
import { MultiSend } from "../../lib/safe-contracts/contracts/libraries/MultiSend.sol";
import { SafeProxyFactory } from "../../lib/safe-contracts/contracts/proxies/SafeProxyFactory.sol";
import { SignMessageLib } from "../../lib/safe-contracts/contracts/libraries/SignMessageLib.sol";

// General setup helper for all safe contracts
abstract contract SafeTestConfig {
    // Safe contract types
    Safe internal safeSingleton;
    MultiSend internal multisend;
    CompatibilityFallbackHandler internal handler;
    SafeProxyFactory internal safeProxyFactory;
    SignMessageLib internal signMessageLib;

    /// -----------------------------------------------------------------------
    /// Setup
    /// -----------------------------------------------------------------------

    constructor() {
        safeSingleton = new Safe();
        multisend = new MultiSend();
        handler = new CompatibilityFallbackHandler();
        safeProxyFactory = new SafeProxyFactory();
        signMessageLib = new SignMessageLib();
    }

    /// -----------------------------------------------------------------------
    /// Utils
    /// -----------------------------------------------------------------------

    function buildSafeMultisend(
        Enum.Operation operation,
        address to,
        uint256 value,
        bytes memory data
    )
        internal
        pure
        returns (bytes memory)
    {
        // Encode the multisend transaction
        // (needed to delegate call from the safe as addModule is 'authorised')
        bytes memory tmp = abi.encodePacked(operation, to, value, uint256(data.length), data);

        // Create multisend payload
        return abi.encodeWithSignature("multiSend(bytes)", tmp);
    }
}
