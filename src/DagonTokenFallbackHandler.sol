// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import { Dagon, IAuth } from "../lib/dagon/src/Dagon.sol";

import "forge-std/console.sol";

/**
 * todo
 * - convert to proxy which groups can set as their own fallback handler
 * - correct IOwnable & enable in Dagon
 */
contract DagonTokenFallbackHandler {
    address public immutable DAGON_SINGLETON;

    constructor(
        address _dagonAddress,
        Dagon.Ownership[] memory owners,
        Dagon.Settings memory setting,
        Dagon.Metadata memory meta
    ) {
        DAGON_SINGLETON = _dagonAddress;

        console.log(DAGON_SINGLETON);

        DAGON_SINGLETON.call(abi.encodeWithSelector(Dagon.install.selector, owners, setting, meta));
    }

    //function requestOwnershipHandover() public payable { }

    receive() external payable {
        console.log("fallback received");
        console.log(msg.value);
    }
}
