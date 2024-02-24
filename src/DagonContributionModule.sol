// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import { Dagon, IAuth } from "../lib/dagon/src/Dagon.sol";

contract DagonContributionModule {
    address public DAGON_SINGLETON = address(0x1);

    constructor() {
        // init this contract with a Dagon token
        Dagon.Ownership[] memory _owners = new Dagon.Ownership[](0);

        Dagon.Settings memory setting;
        setting.token = address(this);
        setting.standard = Dagon.Standard.DAGON;
        setting.threshold = 1; // todo ignore threshold for now

        Dagon.Metadata memory meta;
        meta.name = "";
        meta.symbol = "";
        meta.tokenURI = "";
        meta.authority = IAuth(address(0));
    }
}
