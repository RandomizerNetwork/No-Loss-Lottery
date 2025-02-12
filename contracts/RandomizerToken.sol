// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// ██████   █████  ███    ██ ██████   ██████  ███    ███ ██ ███████ ███████ ██████      ███    ██ ███████ ████████ ██     ██  ██████  ██████  ██   ██ 
// ██   ██ ██   ██ ████   ██ ██   ██ ██    ██ ████  ████ ██    ███  ██      ██   ██     ████   ██ ██         ██    ██     ██ ██    ██ ██   ██ ██  ██  
// ██████  ███████ ██ ██  ██ ██   ██ ██    ██ ██ ████ ██ ██   ███   █████   ██████      ██ ██  ██ █████      ██    ██  █  ██ ██    ██ ██████  █████   
// ██   ██ ██   ██ ██  ██ ██ ██   ██ ██    ██ ██  ██  ██ ██  ███    ██      ██   ██     ██  ██ ██ ██         ██    ██ ███ ██ ██    ██ ██   ██ ██  ██  
// ██   ██ ██   ██ ██   ████ ██████   ██████  ██      ██ ██ ███████ ███████ ██   ██     ██   ████ ███████    ██     ███ ███   ██████  ██   ██ ██   ██ 

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

interface ERC677Receiver {
  function onTokenTransfer(address _sender, uint _value, bytes memory _data) external;
}

contract RandomizerToken is ERC20, ERC20Burnable, ERC20Snapshot, Ownable, ERC20Permit, ERC20Votes {
    uint256 public constant minimumMintInterval = 365 days;
    uint256 public constant mintCap = 100; // 1%
    uint256 public nextMint; // Next Timestamp

    constructor()
        ERC20("Randomizer Network", "RANDOM") 
        ERC20Permit("Randomizer Network")
    {
        _mint(msg.sender, 1000000000 * 10 ** decimals());
        nextMint = block.timestamp + minimumMintInterval;
    }

    function snapshot() public onlyOwner {
        _snapshot();
    }

    /**
     * @dev Mints new tokens. Can only be executed every `minimumMintInterval` by a governance proposal.
     * It cannot exceed 1% of the current total supply.
     * @param to The address to mint the new tokens to.
     * @param amount The quantity of tokens to mint.
     */
    function mint(address to, uint256 amount) public onlyOwner {
        require(amount <= (totalSupply() * mintCap) / 10000, "RANDOM: Mint exceeds maximum amount");
        require(block.timestamp >= nextMint, "RANDOM: Cannot mint yet");
        nextMint = block.timestamp + minimumMintInterval;
        _mint(to, amount);
    }

    /** 
    * @dev ERC677 transfer token to a contract address with additional data if the recipient is a contract.
    * @param _to The address to transfer to.
    * @param _value The amount to be transferred.
    * @param _data The extra data to be passed to the receiving contract.
    */
    function transferAndCall(address _to, uint _value, bytes memory _data) public returns (bool success) {
      require(_msgSender() != address(0), "ERC677: can't receive tokens from the zero address");
      require(_to != address(0), "ERC677: can't send to zero address");
      require(_to != address(this), "ERC677: can't send tokens to the token address");

      _transfer(_msgSender(), _to, _value);
      emit Transfer(_msgSender(), _to, _value);

      if (isContract(_to)) {
        contractFallback(_to, _value, _data);
      }
      return true;
    }

    /**
    * @dev ERC677 function that emits _data to contract.
    * @param _to The address to transfer to.
    * @param _value The amount to be transferred.
    * @param _data The extra data to be passed to the receiving contract.
    */
    function contractFallback(address _to, uint _value, bytes memory _data) private {
      ERC677Receiver receiver = ERC677Receiver(_to);
      receiver.onTokenTransfer(msg.sender, _value, _data);
    }

    /**
    * @dev Helper function that identifies if receiving address is a contract.
    * @param _addr The address to transfer to.
    * @return hasCode The bool that checks if address is an EOA or a Smart Contract. 
    */
    function isContract(address _addr) private view returns (bool hasCode) {
      uint length;
      assembly { length := extcodesize(_addr) }
      return length > 0;
    }

    // The following functions are overrides required by Solidity.
    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Snapshot)
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }

    function destroy() public onlyOwner {
        selfdestruct(payable(owner()));
    }
}