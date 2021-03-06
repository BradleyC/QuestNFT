// SPDX-License-Identifier: MITNFA
pragma solidity ^0.8.4;

import "./IAbstractTask.sol";
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
    mapping (address => bool) isGameMaster;

    struct Quest {
        uint256 questId;
        address questCreator;
        uint256 prerequisiteQuestId;
        uint256 questRewardXP;
        bytes32[] questDescription;
        bytes4[] questTasks;
        // reward logic
    }

    mapping (uint256 => uint256[]) internal questsToTaskAmounts;
    mapping (uint256 => bytes32[]) internal questsToTaskRoots;
    mapping (uint256 => address[]) internal questsToTaskForeignAddress;

    // prototype of all params post-merge
    struct MergedParams {
        uint256 amount; // amount for ERC20 or tokenId for defeating opponent or minimum ETH balance
        bytes32 merkleRoot; // for merkle root OR abstract task
        address foreignAddress; // for ERC721 contract or ERC20 contract or questAgent
        bytes32[] proof; // for merkle root OR abstract task
        bytes32 hashedMessage; // for signed message
        bytes32 _r;
        bytes32 _s;
        uint8 _v; // all 3 for signed message or admitting defeat
        address sender;
        uint256 tokenId;
        uint256 questId;
        uint256 questXp;
    }
    
    Quest[] public quests;

    constructor(uint256 _publicMintPrice, uint256 _registerQuestCost) ERC721("QuestNFT", "QNFT") {
        isGameMaster[msg.sender] = true;
        publicMintPrice = _publicMintPrice;
        registerQuestCost = _registerQuestCost;
        _nextId = 0;
    }

    function registerQuest(
            uint256 xp, 
            bytes32[] calldata questDescription, 
            uint256[] calldata paramAmount, 
            bytes32[] calldata root, 
            address[] calldata fAddress,
            bytes4[] calldata tasks) 
            public payable returns (bool success) {
                require(isGameMaster[msg.sender], 'only the wisened may create quests');
                require(msg.value >= registerQuestCost);
                require(xp < 25, 'no person levels up that quickly');
                Quest memory q;
                q.questId = quests.length + 1;
                q.questCreator = msg.sender;
                q.questRewardXP = xp;
                q.questDescription = questDescription;
                q.questTasks = tasks;
                quests.push(q);
                for (uint256 i = 0; i < paramAmount.length; i++) {
                    questsToTaskAmounts[q.questId].push(paramAmount[i]);
                    questsToTaskRoots[q.questId].push(root[i]);
                    questsToTaskForeignAddress[q.questId].push(fAddress[i]);
                }
                return true;
    }

    // ============ EVALUATOR ============
    
    function getQuestTasks(uint256 questId) public view returns (bytes4[] memory tasks) {
        require(questId <= quests.length);
        return quests[questId].questTasks;
    }

    function getQuestTaskParams(uint256 questId) public view returns (uint256[] memory amounts, bytes32[] memory roots, address[] memory foreignAddresses) {
        require(questId <= quests.length);
        return (questsToTaskAmounts[questId], questsToTaskRoots[questId], questsToTaskForeignAddress[questId]);
    }

    function getTaskCount(uint256 questId) public view returns (uint256 count) {
        require(questId <= quests.length);
        return quests[questId].questTasks.length;
    }

    function evaluateQuestStatus(
        uint256 tokenId, 
        uint256 questId, 
        bytes32[][] calldata proof, 
        bytes32[] calldata message, 
        bytes32[] calldata r, 
        bytes32[] calldata s, 
        uint8[] calldata v) public {
            Quest memory q = quests[questId];
            require(isQuestCompletedByTokenId[tokenId][q.prerequisiteQuestId] == true, 'Must complete prerequisite quest');
            require(!isTokenIdBannedFromQuest[tokenId][questId] && !isQuestCompletedByTokenId[tokenId][questId], 'Already completed or BANNED');
            require(msg.sender == ownerOf(tokenId), 'Only owner can evaluate quest status');
            MergedParams[] memory m;
            for (uint256 i = 0; i < q.questTasks.length; i++) {
                // from storage
                m[i].amount = questsToTaskAmounts[questId][i];
                m[i].merkleRoot = questsToTaskRoots[questId][i];
                m[i].foreignAddress = questsToTaskForeignAddress[questId][i];
                // from input
                m[i].proof = proof[i];
                m[i].hashedMessage = message[i];
                m[i]._r = r[i];
                m[i]._s = s[i];
                m[i]._v = v[i];
                m[i].sender = msg.sender;
                m[i].tokenId = tokenId;
                m[i].questId = questId;
                m[i].questXp = q.questRewardXP;
            } 
            for (uint256 i = 0; i < q.questTasks.length; i++) {
                bool qBool;
                bytes memory result;
                (qBool, result) = address(this).call(abi.encodeWithSelector(q.questTasks[i], m[i]));
                require(qBool, 'Task failed');
            }
            updateTokenScore(tokenId, questId, q.questRewardXP);
    }

    // ============ QUEST FUNCTIONS ============

    // Obtain a given NFT
    function ownerOfNFTTask(MergedParams calldata m) internal view returns (bool completed) {
        address playerAddress = m.sender;
        uint256 amount = m.amount;
        address ERC721Contract = m.foreignAddress;
        ERC721 nftContract = ERC721(ERC721Contract);
        if (nftContract.balanceOf(playerAddress) >= amount) {
            return true;
        }
        return false;
    }

    // Obtain a balance of given ERC20 token
    function ownerOfERC20Task(MergedParams calldata m) internal view returns (bool completed) {
        address playerAddress = m.sender;
        address ERC20contract = m.foreignAddress;
        uint256 amount = m.amount;
        ERC20 tokenContract = ERC20(ERC20contract);
        if (tokenContract.balanceOf(playerAddress) >= amount) {
            return true;
        }
        return false;
    }

    // Bring back a signed message from a specific address
    function bearerOfSignedMessageTask(MergedParams calldata m) internal pure returns (bool completed) {
        bytes32 _hashedMessage = m.hashedMessage;
        uint8 _v = m._v;
        bytes32 _r = m._r;
        bytes32 _s = m._s;
        address questAgent = m.foreignAddress;
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
    function memberOfMerkleTreeTask(MergedParams calldata m) internal view returns (bool completed) {
        bytes32[] calldata proof = m.proof;
        bytes32 merkleRoot = m.merkleRoot;
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(proof, merkleRoot, leaf),'MemberOfMerkleTreeTask: proof is not valid');
        return true;
    }

    // Get other player to admit defeat
    // Message format: "I admit defeat. [tokenId] in quest [questId]."
    function defeatOpponentTask(MergedParams calldata m) internal returns(bool completed) {
        uint8 _v = m._v;
        bytes32 _r = m._r;
        bytes32 _s = m._s;
        uint256 questId = m.questId;
        uint256 opponentTokenId = m.amount;
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes memory admission = abi.encodePacked('I admit defeat. ', Strings.toString(opponentTokenId), ' in quest ', Strings.toString(questId));
        bytes32 prefixedHashMessage = keccak256(abi.encodePacked(prefix, admission));
        address signer = ecrecover(prefixedHashMessage, _v, _r, _s);
        // TODO: This is broken because player could transfer their token after signing.
        //       Fix: override transfer and use governor bravo style snapshots as of block numbers.
        require(signer == ownerOf(opponentTokenId), "NO!");
        // forward to funbug reward contract (?)
        xpByTokenId[opponentTokenId] -= m.questXp;
        isTokenIdBannedFromQuest[questId][opponentTokenId] = true;
        return true;
    }

    // Check if player has met an ETH balance threshold
    function ETHMinimumBalanceTask(MergedParams calldata m) internal view returns (bool completed) {
        uint256 minimumBalance = m.amount;
        address playerAddress = m.sender;
        require(playerAddress.balance >= minimumBalance, "ETHMinimumBalanceTask: not enough ETH");
        return true;
    }

    function completeAbstractTask(MergedParams calldata m) private returns (bool) {
        IAbstractTask abstractTaskContract = IAbstractTask(m.foreignAddress);
        bytes32[] memory abstractTaskData = m.proof;
        require(abstractTaskContract.evaluate(abstractTaskData), "AbstractTask: Did not pass");
        return true;
    }

    // ============ UTILITIES ============

    function mint(address to) public payable publicMintPaid {
        _mint(to, _nextId++);
    }

    function addGameMaster(address gm) public onlyOwner {
        isGameMaster[gm] = true;
    }

    function removeGameMaster(address gm) public onlyOwner {
        isGameMaster[gm] = false;
    }

    function updateTokenScore(uint256 tokenId, uint256 questId, uint256 xp) internal {
        xpByTokenId[tokenId] += xp;
        isQuestCompletedByTokenId[tokenId][questId] = true;
        questCompletedCountByTokenId[tokenId]++;
    }

    // ============ MODIFIERS ============

    modifier publicMintPaid {
        require(msg.value == publicMintPrice, 'QuestNFT: invalid mint fee');
        _;
    }

    modifier onlyTokenOwner(uint256 tokenId) {
        require(msg.sender == ERC721.ownerOf(tokenId), 'QuestNFT: only owner can attempt a quest');
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
            '</text><text x="20" y="240" font-size="22" fill="white">Quests completed: ',
            questCompletedCountByTokenId[tokenId],
            '</text><text x="20" y="280" font-size="22" fill="white">Current XP: ',
            xpByTokenId[tokenId],
            '</text></svg>'
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
