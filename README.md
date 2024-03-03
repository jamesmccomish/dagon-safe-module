# Dagon Safe Contribution Module 

[Dagon](https://github.com/Moloch-Mystics/dagon) is a singleton contract which allows accounts to extend their functionality with token tracking and proposal voting. This module is designed to enable a Safe to track the contributions of members by minting a Dagon token. 

## Current State

- Can handle contributions made by native curreny, or by ERC20 tokens sent via transferFrom
- Safe can [install](/src/DagonTokenModule.sol#L63) the module, [set which tokens are tracked](/src/DagonTokenModule.sol#L93) for contributions, and [set the exchange rate](/src/DagonTokenModule.sol#L43) for each token
- Handling of voting weight and execution based on token share is not yet implemented


## Warning ⚠️
Still in testing and not ready for production use.
