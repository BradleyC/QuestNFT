// SPDX-License-Identifier: MITNFA
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import 'base64-sol/base64.sol';

contract QuestNFT is ERC721, Ownable, Pausable {
    uint256 public publicMintPrice;
    uint256 internal _nextId;
    uint256 public registerQuestCost;

    // ============ QUEST REGISTRY ============

    mapping(uint256 => uint256) public xpByTokenId;
    mapping(uint256 => mapping(uint256 => bool)) public isQuestCompletedByTokenId;
    mapping(uint256 => uint256) public questCompletedCountByTokenId;
    mapping(uint256 => uint256[]) public questsInProgressPerToken;
    mapping (uint256 => mapping (uint256 => bool)) isTokenIdBannedFromQuest;

    struct Quest {
        uint256 questId;
        address questCreator;
        uint256 prerequisiteQuestId;
        uint256 questRewardXP;
        address[] questPlayers;
        bytes32[] questDescription;
        bytes4[] questTasks;
        TaskParams[] taskParams;
        // reward logic
    }

    struct QuestParams {
        uint256 amount; // amount for ERC20 or tokenId for defeating opponent or minimum ETH balance
        bytes32 merkleRoot; // for merkle root OR abstract task
        address foreignAddress; // for ERC721 contract or ERC20 contract or questAgent
    }

    Quest[] public quests;

    function registerQuest() public payable {
        return false;
    }

    // ============ EVALUATOR ============
    
    function evaluateQuestStatus(uint256 tokenId, uint256 questId) public {
        Quest memory q = quests[questId];
        require(isQuestCompletedByTokenId[tokenId][q.prerequisiteQuestId] == true, 'Must complete prerequisite qeust');
        require(!isTokenIdBannedFromQuest[tokenId][questId] && !isQuestCompletedByTokenId[tokenId][questId], 'Already completed or BANNED');
        require(msg.sender == ownerOf(tokenId), 'Only owner can evaluate quest status');
        for (uint256 i = 0; i < q.questTasks.length; i++) {
            TaskParams p = q.taskParams[i];
            // might need to concatenate function signature + args into bytes
            // pass in message.sender
            require(this.call(q.questTasks[i], p) == true, 'Quest goal not met');
            xpByTokenId[tokenId] += q.questRewardXP;
            questcompletedByTokenId[tokenId][questId] = true;
            questCompletedCountByTokenId[tokenId]++;
            }
        }
    }

    // ============ QUEST FUNCTIONS ============

    // TODO: add all unique params to TaskParams enum && accept TaskParams as argument && unpack TaskParams into individual params

    // Obtain a given NFT
    function ownerOfNFTTask(address ERC721contract) internal returns (bool) {
        address playerAddress = msg.sender;
        ERC721 nftContract = ERC721(ERC721contract);
        if (nftContract.balanceOf(playerAddress) >= 1) {
            return true;
        }
        return false;
    }

    // Obtain a balance of given ERC20 token
    function ownerOfERC20Task(address ERC20contract, uint256 amount) internal returns (bool) {
        address playerAddress = msg.sender;
        ERC20 tokenContract = ERC20(ERC20contract);
        if (tokenContract.balanceOf(playerAddress) >= amount) {
            return true;
        }
        return false;
    }

    // Bring back a signed message from a specific address
    function bearerOfSignedMessageTask(bytes32 _hashedMessage, uint8 _v, bytes32 _r, bytes32 _s, address questAgent) internal pure returns (bool complete) {
        // Thank u Chainsafe Leon Do https://blog.chainsafe.io/how-to-verify-a-signed-message-in-solidity-6b3100277424
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 prefixedHashMessage = keccak256(abi.encodePacked(prefix, _hashedMessage));
        address signer = ecrecover(prefixedHashMessage, _v, _r, _s);
        // TODO: check if signer is the same as msg.sender, return something other than 'signer'
        require(signer == questAgent, 'BearerOfSignedMessageTask: signer is not the official Quest Agent');
        return true;
    }
    
    // Be a part of a merkle tree
    // use preset (per quest) merkle tree
    function memberOfMerkleTreeTask(bytes32[] calldata proof, bytes32[] calldata merkleRoot) internal returns (bool complete) {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(proof, merkleRoot, leaf),'MemberOfMerkleTreeTask: proof is not valid');
        return true;
    }

    // Get other player to admit defeat
    // Message format: "I admit defeat. [tokenId] in quest [questId]."
    function defeatOpponentTask(uint8 _v, bytes32 _r, bytes32 _s, uint256 questId, uint256 opponentTokenId) internal returns(bool) {
        address playerAddress = msg.sender;
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes memory admission = abi.encodePacked('I admit defeat. ', Strings.toString(opponentTokenId), ' in quest ', Strings.toString(questId));
        bytes32 prefixedHashMessage = keccak256(abi.encodePacked(prefix, admission));
        address signer = ecrecover(prefixedHashMessage, _v, _r, _s);
        // TODO: This is broken because player could transfer their token after signing.
        //       Fix: override transfer and use governor bravo style snapshots as of block numbers.
        require(signer == ownerOf(opponentTokenId), "NO!");
        return true;
    }

    // Check if player has met an ETH balance threshold
    function ETHMinimumBalanceTask(uint256 minimumBalance) internal returns (bool completed) {
        address playerAddress = msg.sender;
        require(playerAddress.balance >= minimumBalance, "ETHMinimumBalanceTask: not enough ETH");
        return true;
    }

    function completeAbstractTask() private returns (bool) {
        return true;
    }

    // ============ UTILITIES ============

    function mint(address to) public payable publicMintPaid {
        _mint(to, _nextId);
        _nextId++;
    }

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