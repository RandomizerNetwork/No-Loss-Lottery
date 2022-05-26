// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

// ███    ███ ███████ ████████  █████       ██████   █████  ███    ███ ███████     ██████   █████  ███████ ███████ 
// ████  ████ ██         ██    ██   ██     ██       ██   ██ ████  ████ ██          ██   ██ ██   ██ ██      ██      
// ██ ████ ██ █████      ██    ███████     ██   ███ ███████ ██ ████ ██ █████       ██████  ███████ ███████ ███████ 
// ██  ██  ██ ██         ██    ██   ██     ██    ██ ██   ██ ██  ██  ██ ██          ██      ██   ██      ██      ██ 
// ██      ██ ███████    ██    ██   ██      ██████  ██   ██ ██      ██ ███████     ██      ██   ██ ███████ ███████ 

import "./@openzeppelin/contracts/token/ERC721A/ERC721A.sol";
import "./@openzeppelin/contracts/token/ERC721A/ContextMixin.sol";
import "./@openzeppelin/contracts/token/ERC721A/NativeMetaTransaction.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

contract RandomizerMetaGamePass is ERC721A, ERC2981, ContextMixin, NativeMetaTransaction, Ownable {

    uint256 public constant MAX_GAME_PASSES = 5000;
    uint256 public allowMintingAfter;
    uint256 public timeDeployed;
    bool public claimedReserve;

    // 10% -> 100M RANDOM / 3650 days = 27397,26 RANDOM Tokens Daily
    // uint256 public DAILY_METAPASS_REWARD = 10; // 10 RANDOM * 50 Winners Daily = 500 RANDOM * 3650 days = 1.825.000 RANDOM in 10 years 

    // 1, "0xe6F7C7caF678A3B7aFb93891907873E88F4FD4AC", 500, "Randomizer Meta Pass", "RMP", 500
    constructor(        
        string memory _name,           // Randomizer Meta Pass
        string memory _symbol,         // RMP Symbol
        uint256 _allowMintingOn,       // minting start date 
        address _royaltiesReceiver,    // GNOSIS MULTISIG SAFE 
        uint96 _royaltiesFeeNumerator, // ongoing royalty fees 
        uint256 _maxBatchSize          // maximum mint size used for the reserve
    ) ERC721A(_name, _symbol, _maxBatchSize) {
        _initializeEIP712(_name);
        allowMintingAfter = _allowMintingOn > block.timestamp ? _allowMintingOn - block.timestamp : 0;
        timeDeployed = block.timestamp;
        _setDefaultRoyalty(_royaltiesReceiver, _royaltiesFeeNumerator);
    }

    function mint(address to, uint256 quantity) public payable {
        require(block.timestamp >= timeDeployed + allowMintingAfter, "Minting now allowed yet");
        require(totalSupply() + quantity <= MAX_GAME_PASSES, "Max Supply Reached");

        if (msg.sender != owner()) {
            require(quantity > 0 && quantity <= 2, "Max 2 Meta Passes per wallet");
            require(to == msg.sender, "Can only mint tokens for yourself");
            require(msg.value >= 0.05 ether * quantity, "");
            _safeMint(to, quantity);
        } else {
            require(claimedReserve == false, "Team should not have minted reserved tokens");
            _safeMint(0xe6F7C7caF678A3B7aFb93891907873E88F4FD4AC, 125); // Collaborators, Marketing, Advisors
            _safeMint(msg.sender, 500); // Core Team
            claimedReserve = true;
        }
    }

    function getSecondsUntilMinting() public view returns (uint256) {
        if (block.timestamp < timeDeployed + allowMintingAfter) {
            return (timeDeployed + allowMintingAfter) - block.timestamp;
        } else {
            return 0;
        }
    }

    function tokenURI(uint256 tokenId) public pure override(ERC721A) returns (string memory) {
        require(tokenId <= MAX_GAME_PASSES);
        return _baseURI();
    }

    function setRoyaltyInfo(address receiver, uint96 feeBasisPoints) external onlyOwner {
        _setDefaultRoyalty(receiver, feeBasisPoints);
    }

    function withdraw() public payable onlyOwner {
        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(success);
    }

    /**
   * Override isApprovedForAll to auto-approve OS's proxy contract
   */
    function isApprovedForAll(
        address _owner,
        address _operator
    ) public override view returns (bool isOperator) {
        uint256 chainId;
        
        assembly {
            chainId := chainid()
        }

        // if OpenSea's ERC721 Proxy Address is detected, auto-return true
        if (chainId == 1 && _operator == 0xa5409ec958C83C3f309868babACA7c86DCB077c1) {
            return true;
        }
        if (chainId == 137 && _operator == 0x58807baD0B376efc12F5AD86aAc70E78ed67deaE) {
            return true;
        }
        if (chainId == 4 && _operator == 0x1E525EEAF261cA41b809884CBDE9DD9E1619573A) {
            return true;
        }
        if (chainId == 80001 && _operator == 0xff7Ca10aF37178BdD056628eF42fD7F799fAc77c) {
            return true;
        }
        
        // otherwise, use the default ERC721.isApprovedForAll()
        return ERC721A.isApprovedForAll(_owner, _operator);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721A, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _baseURI() internal pure override(ERC721A) returns (string memory) {
        return "ipfs://bafybeicwk5gf5sw7ti5gr7t776aijcfy2ufnffsafnxyc7bqpumkgiskxy";
    }

    function contractURI() public pure returns (string memory) {
        return "ipfs://QmTnq4ZSUqAuqerZtrhatrBAHYkUzjgFhxwZyBpA5aBz93"; // Contract-level metadata for OpenSea
    }

    /**
     * This is used instead of msg.sender as transactions won't be sent by the original token owner, but by OpenSea.
    */
    function _msgSender()
        internal
        override
        view
        returns (address sender)
    {
        return ContextMixin.msgSender();
    }
}