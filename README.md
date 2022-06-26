# Quest NFT

## One-liner
Smart contract framework for quest-based games. Players get NFT accounts that they can use to complete quests and earn XP.

## Overview
QuestNFT is a smart contract implementation that allows anyone to create and run a quest-based game. In QuestNFT, players mint NFTs which are used as their on-chain save files. These NFTs can earn XP as players complete various quests. The power of QuestNFT is a flexible and composable quest structure that allows the game masters to create a variety of challenges for players. QuestNFT provides built-in task types that a game master can mix and match in a given quest. Game masters can keep adding more quests indefinitely, allowing for an ongoing game that evolves over time.

## NFTs

The QuestNFT.sol contract allows players to mint QuestNFTs. Each NFT acts like a player's save file and keeps track of its XP and completed quests.

Each QuestNFT is rendered as on-chain SVG displaying its XP and number of quests completed.

## Game Masters

There is a `GameMaster` role within a QuestNFT contract. Game masters are responsible for adding new quests.

Only the owner of the contract can add and remove game masters.

## Quests

### What is a quest?

A quest is an on-chain mission. Quests can be added by game masters, providing new challenges for players to complete.

Each Quest is made up of one or more Tasks. Tasks are functions that take in parameters and evaluate to True or False based on their own logic.

### Creating quests

When adding a new Quest, a game master can mix and match lots of different kinds of Tasks. QuestNFT provides a number of built-in Task types, as well as a catch-all abstract Task type. Below is a summary of what's built-in:
- **ERC20 balance check**: Makes sure that a player has a balance greater than or equal to an `amount` for a specific ERC20 token.
- **NFT ownership check**: Makes sure that a player owns an NFT in a specific collection.
- **Merkle Tree inclusion check**: Makes sure a player's address is a leaf in a given merkle tree.
- **Signed message check**: Requires the player to provide a message signed by a Quest's `questAgent` (similar to the dungeon master for this quest)
- **Admission of defeat**: Requires the player to provide a message from another player, admitting defeat.
- **Abstract task**: A smart contract interface that can be implemented with any logic for checking whether or not it has been completed. This allows game masters to implement more custom quests if they want to.

### Completing a quest

In order to complete a Quest, a player must call the `evaluateQuestStatus` function, passing in their `tokenId` and any Task parameters that are required. To completed the Quest, all Tasks within the Quest must return `true` simultaneously.

Each Quest is worth a specific amount of XP, set by the game master who created it. When a player completes a quest, XP is added to their `tokenId`.

### Quest data model

Quests are stored using the following struct:
```
struct Quest {
        // Index of this quest in the quests array
        uint256 questId;
        // Creator of this quest
        address questCreator;
        // Optional: a quest you must have completed before completing this quest
        uint256 prerequisiteQuestId;
        // How much XP a player gets for completing this quest
        uint256 questRewardXP;
        // Human readable string describing this quest
        bytes32[] questDescription;
        // Function signatures of Tasks in this quest
        bytes4[] questTasks;
        // Information required to evaluate Tasks in this quest
        TaskParams[] taskParams;
        // reward logic
    }
```
