/**
 * This smart contract code is Copyright 2017 TokenMarket Ltd. For more information see https://tokenmarket.net
 *
 * Licensed under the Apache License, version 2.0: https://github.com/TokenMarketNet/ico/blob/master/LICENSE.txt
 */

pragma solidity ^0.4.18;

import "./UpgradeableToken.sol";
import "./ReleasableToken.sol";
import "./MintableToken.sol";
import "./ITokenEventListener.sol";


/**
 * A DAICO alternative to crowdsale token.
 *
 * An ERC-20 token designed specifically for crowdsales with investor protection and further development path.
 *
 * - The token transfer() is disabled until the crowdsale is over
 * - The token contract gives an opt-in upgrade path to a new contract
 * - The same token can be part of several crowdsales through approve() mechanism
 * - The token can be capped (supply set in the constructor) or uncapped (crowdsale contract can mint new tokens)
 *
 */
contract DaicoToken is ReleasableToken, MintableToken, UpgradeableToken {

  // Event listener user to notify the DAICO about token transfer.
  ITokenEventListener public eventListener;

  /** Name and symbol were updated. */
  event UpdatedTokenInformation(string newName, string newSymbol);

  string public name;

  string public symbol;

  uint public decimals;

  /**
   * Construct the token.
   *
   * This token must be created through a team multisig wallet, so that it is owned by that wallet.
   *
   * @param _name Token name
   * @param _symbol Token symbol - should be all caps
   * @param _initialSupply How many tokens we start with
   * @param _decimals Number of decimal places
   * @param _mintable Are new tokens created over the crowdsale or do we distribute only the initial supply? Note that when the token becomes transferable the minting always ends.
   */
  function DaicoToken(string _name, string _symbol, uint _initialSupply, uint _decimals, bool _mintable)
  UpgradeableToken(msg.sender) {

    // Create any address, can be transferred
    // to team multisig via changeOwner(),
    // also remember to call setUpgradeMaster()
    owner = msg.sender;

    name = _name;
    symbol = _symbol;

    totalSupply = _initialSupply;

    decimals = _decimals;

    // Create initially all balance on the team multisig
    balances[owner] = totalSupply;

    if(totalSupply > 0) {
      Minted(owner, totalSupply);
    }

    // No more new supply allowed after the token creation
    if(!_mintable) {
      mintingFinished = true;
      if(totalSupply == 0) {
        throw; // Cannot create a token without supply and no minting
      }
    }
  }

  /**
   * When token is released to be transferable, enforce no new tokens can be created.
   */
  function releaseTokenTransfer() public onlyReleaseAgent {
    mintingFinished = true;
    super.releaseTokenTransfer();
  }

  /**
   * Allow upgrade agent functionality kick in only if the crowdsale was success.
   */
  function canUpgrade() public constant returns(bool) {
    return released && super.canUpgrade();
  }

  /**
   * Owner can update token information here.
   *
   * It is often useful to conceal the actual token association, until
   * the token operations, like central issuance or reissuance have been completed.
   *
   * This function allows the token owner to rename the token after the operations
   * have been completed and then point the audience to use the token contract.
   */
  function setTokenInformation(string _name, string _symbol) onlyOwner {
    name = _name;
    symbol = _symbol;

    UpdatedTokenInformation(name, symbol);
  }

  /**
* @dev Set/remove token event listener
* @param _listener Listener address (Contract must implement ITokenEventListener interface)
*/
  function setListener(address _listener) public onlyOwner {
    if(_listener != address(0)) {
      eventListener = ITokenEventListener(_listener);
    } else {
      delete eventListener;
    }
  }

  function hasListener() internal view returns(bool) {
    if(eventListener == address(0)) {
      return false;
    }
    return true;
  }

  function transfer(address _to, uint256 _value) public returns (bool) {
    bool isSuccessful = super.transfer(_to, _value);
    if (hasListener() && isSuccessful) {
      eventListener.onTokenTransfer(msg.sender, _to, _value);
    }
    return isSuccessful;
  }

  function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
    bool isSuccessful = super.transferFrom(_from, _to, _value);
    if (hasListener() && isSuccessful) {
      eventListener.onTokenTransfer(_from, _to, _value);
    }
    return isSuccessful;
  }
}
