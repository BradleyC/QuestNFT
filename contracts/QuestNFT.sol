// SPDX MITNFA
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import 'base64-sol/base64.sol';

contract QuestNFT is ERC721, Ownable, Pausable, MerkleProof {
    uint256 publicMintPrice;
    uint256 internal _nextId;

    mapping(uint256 => uint256) xpByTokenId;
    mapping(uint256 => mapping(uint256 => bool)) questCompletedByTokenId;

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
    function BearerOfSignedMessageTask(bytes32 _hashedMessage, uint8 _v, bytes32 _r, bytes32 _s, address questAgent) public pure returns (bool complete) {
        // Thank u Chainsafe Leon Do https://blog.chainsafe.io/how-to-verify-a-signed-message-in-solidity-6b3100277424
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 prefixedHashMessage = keccak256(abi.encodePacked(prefix, _hashedMessage));
        address signer = ecrecover(prefixedHashMessage, _v, _r, _s);
        // TODO: check if signer is the same as msg.sender, return something other than 'signer'
        require(signer == questAgent, 'BearerOfSignedMessageTask: signer is not the official Quest Agent');
        return true;
    }
    
    // be a part of a merkle tree
    function MemberOfMerkleTreeTask(bytes32[] calldata proof, bytes32[] calldata merkleRoot) internal returns (bool complete) {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(proof, merkleRoot, leaf),'MemberOfMerkleTreeTask: proof is not valid');
        return true;
    }

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

    // Check if player has met an ETH balance threshold
    function ETHMinimumBalanceTask(uint256 minimumBalance) public returns (bool completed) {
        address playerAddress = msg.sender;
        require(playerAddress.balance >= minimumBalance, "ETHMinimumBalanceTask: not enough ETH");
        return true;
    }

    // Quest NFT Utility Functions

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
    
    function generateSVG(uint256 tokenId) internal view returns (bytes memory svg) {
        svg = abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300" style="background:#000"><rect fill="green" x="0" y="0" width="300" height="50"></rect><text x="20" y="33" font-size="22" fill="white">Quest NFT #',
            tokenId,
            '</text><text x="20" y="280" font-size="22" fill="white">Current XP: ',
            xpByTokenId[tokenId],
            '</text></svg>'
            '"</text></svg>'
        );
    }
    
    // ============ METADATA ============

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return
            string(
                abi.encodePacked(
                    'data:application/json;base64,',
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name":"QuestNFT",',
                                '"image":"data:image/svg+xml;base64,',
                                Base64.encode(bytes(generateSVG(tokenId))),
                                '", "description": "NFT that can beat quests and earn XP.",',
                                '"xp": "',
                                xpByTokenId[tokenId],
                                '"}'
                            )
                        )
                    )
                )
            );
    }
}