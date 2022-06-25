// SPDX MITNFA
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract QuestNFT is ERC721, Ownable, Pausable {
    uint256 publicMintPrice;
    uint256 internal _nextId;

    // ============ MODIFIERS ============

    modifier publicMintPaid() {
        require(msg.value == publicMintPrice, 'QuestNFT: invalid mint fee');
        _;
    }

    modifier onlyTokenOwner(uint256 tokenId) {
        require(msg.sender == ERC721.ownerOf(tokenId), 'QuestNFT: only owner can build Shield');
        _;
    }

    // ============ OWNER INTERFACE ============

    function collectFees() external onlyOwner {
        (bool success, ) = payable(msg.sender).call{value: address(this).balance}(new bytes(0));
        require(success, 'QuestNFT: ether transfer failed');
    }

    function setPublicMintPrice(uint256 _publicMintPrice) external onlyOwner {
      publicMintPrice = _publicMintPrice;
    }

    // Quest Registry
    struct Quest {
        uint256 questId;
        address questCreator;
        uint256 prerequisiteQuest;
        uint256 questRewardXP;
        address[] questPlayers;
        bytes4[] questGoals;
    }

    function mint(address to) public payable publicMintPaid {
        _mint(to, _nextId++);
    }

    // Evaluator

    // Base Quest Functions
    // do you own X NFT
    function OwnerOfNFTTask(address ERC721contract) public returns (bool) {
        address playerAddress = msg.sender;
        ERC721 nftContract = ERC721(ERC721contract);
        if (nftContract.balanceOf(playerAddress) >= 1) {
            return true;
        }
        return false;
    }

    // did you have enough of this ERC20
    function OwnerOfERC20Task(address ERC20contract, uint256 amount) public returns (bool) {
        address playerAddress = msg.sender;
        ERC20 tokenContract = ERC20(ERC20contract);
        if (tokenContract.balanceOf(playerAddress) >= amount) {
            return true;
        }
        return false;
    }
    
    // bring back a signed message from a specific address
    function BearerOfSignedMessageTask(bytes32 _hashedMessage, uint8 _v, bytes32 _r, bytes32 _s) public pure returns (address) {
        // Thank u Chainsafe Leon Do https://blog.chainsafe.io/how-to-verify-a-signed-message-in-solidity-6b3100277424
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 prefixedHashMessage = keccak256(abi.encodePacked(prefix, _hashedMessage));
        address signer = ecrecover(prefixedHashMessage, _v, _r, _s);
        // TODO: check if signer is the same as msg.sender, return something other than 'signer'
        return signer;
    }
    // be a part of a merkle tree
    
    // get other player to admit defeat
    // Message format: "I admit defeat. [tokenId] in quest [questId] at [blockNumber]."
    function DefeatOpponentTask(uint8 _v, bytes32 _r, bytes32 _s, uint256 questId, uint256 opponentTokenId) public returns(bool) {
        address playerAddress = msg.sender;
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes memory admission = abi.encodePacked('I admit defeat. ', opponentTokenId, ' in quest ', questId);
        bytes32 prefixedHashMessage = keccak256(abi.encodePacked(prefix, admission));
        address signer = ecrecover(prefixedHashMessage, _v, _r, _s);
        // TODO: This is broken because player could transfer their token after signing.
        //       Fix: override transfer and use governor bravo style snapshots as of block numbers.
        require(signer == ownerOf(opponentTokenId), "NO!");
        return true;
    }

    // ~~nonce above X~~
    // do you own > X amount of ETH

    // Quest NFT Utility Functions

    // Quest NFT Modifiers
    

}