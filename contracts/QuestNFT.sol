// SPDX MITNFA
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract QuestNFT is ERC721, Ownable, Pausable {
    // Quest Registry
    struct Quest {
        uint256 questId;
        address questCreator;
        uint256 prerequisiteQuest;
        uint256 questRewardXP;
        address[] questPlayers;
        bytes4[] questGoals;
    }

    // Mint Quest NFT

    // Evaluator

    // Base Quest Functions
    // do you own X NFT
    function OwnerOfNFTTask(address NFTcontract) {
        address playerAddress = msg.sender;
        // take playerAddress, check if playerAddress is owner in given NFT contract
        // @JP how does basic ERC721 return if you own a token?
        // ideally we don't need a tokenID
    }
    // did you have enough of this ERC20
    function OwnerOfERC20Task(address ERC20contract, uint256 amount) {
        address playerAddress = msg.sender;
        // take playerAddress, check if playerAddress has enough of given ERC20 contract
        // @JP how does basic ERC20 return if you own a token?
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
    function DefeatOpponentTask(address opponent, uint8 _v, bytes32 _r, bytes32 _s) public {
        address playerAddress = msg.sender;
        // take playerAddress, check if playerAddress is owner in given NFT contract
        // create constant message hash of phrase "I admit defeat"
        // verify opponent signed message
        // alternative: verify signature and parse addresses from message..
        bytes32 prefixedHashMessage = keccak256(abi.encodePacked(prefix, _hashedMessage));
        address signer = ecrecover(prefixedHashMessage, _v, _r, _s);
        // (incomplete)
    }
    // ~~nonce above X~~
    // do you own > X amount of ETH

    // Quest NFT Utility Functions

    // Quest NFT Modifiers


}