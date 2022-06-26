# Quest NFT
Smart contract framework for quest-based games. Players get NFT accounts that they can use to complete quests and earn XP.

### NFTs

The QuestNFT.sol contract allows players to mint QuestNFTs. Each NFT acts like a player's save file and keeps track of its XP and completed quests.

Each QuestNFT is rendered as on-chain SVG displaying its XP and number of quests completed.

### Quests

Quests can be added by the owner of the the QuestNFT instance, providing new challenges for players to complete.

Each Quest is made up of one or more Tasks. Tasks are functions that take in parameters and evaluate to True or False based on their own logic.

In order to complete a Quest, a player must call the `evaluateQuestStatus` function, passing in their `tokenId` and ensuring that all Tasks within the Quest return `true` simultaneously.

Each Quest is worth a specific amount of XP, set by the contract owner. When a player completes a quest, XP is added to their `tokenId`.

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

### Tasks

QuestNFT supports a number of built-in Tasks types, as well as a catch-all abstract Task type.

When adding a new Quest, the contract owner can mix and match any number of these Tasks into the Quest:
- **ERC20 balance check**: Makes sure that a player has a balance greater than or equal to an `amount` for a specific ERC20 token.
- **NFT ownership check**: Makes sure that a player owns an NFT in a specific collection.
- **Merkle Tree inclusion check**: Makes sure a player's address is a leaf in a given merkle tree.
- **Signed message check**: Requires the player to provide a message signed by a Quest's `questAgent` (similar to the dungeon master for this quest)
- **Admission of defeat**: Requires the player to provide a message from another player, admitting defeat.
- **Abstract task**: A smart contract interface that can be implemented with any logic for checking whether or not it has been completed. Can be written and deployed by the contract owner.
