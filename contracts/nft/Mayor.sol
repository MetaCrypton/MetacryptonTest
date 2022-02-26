// SPDX-License-Identifier: Apache 2.0
// Copyright © 2021 Anton "BaldyAsh" Grigorev. All rights reserved.

pragma solidity ^0.8.0;

import "./IMayor.sol";
import "./NFT.sol";

contract Mayor is IMayor, NFT {
    error EmptyName();
    error SameValue();
    error WrongLevel();

    uint256 internal constant LEVELS_NUMBER = 3;

    uint256 internal constant VOTE_PRICE = 0.001 ether;

    uint8 internal constant HASHRATE_MULTIPLIERS_COMMON_GEN0 = 10;
    uint8 internal constant HASHRATE_MULTIPLIERS_COMMON_GEN1 = 40;
    uint8 internal constant HASHRATE_MULTIPLIERS_COMMON_GEN2 = 120;

    uint8 internal constant HASHRATE_MULTIPLIERS_RARE_GEN0 = 10;
    uint8 internal constant HASHRATE_MULTIPLIERS_RARE_GEN1 = 30;
    uint8 internal constant HASHRATE_MULTIPLIERS_RARE_GEN2 = 75;

    uint8 internal constant HASHRATE_MULTIPLIERS_EPIC_GEN0 = 10;
    uint8 internal constant HASHRATE_MULTIPLIERS_EPIC_GEN1 = 25;
    uint8 internal constant HASHRATE_MULTIPLIERS_EPIC_GEN2 = 50;

    uint8 internal constant HASHRATE_MULTIPLIERS_LEGENDARY_GEN0 = 10;
    uint8 internal constant HASHRATE_MULTIPLIERS_LEGENDARY_GEN1 = 20;
    uint8 internal constant HASHRATE_MULTIPLIERS_LEGENDARY_GEN2 = 30;

    uint8 internal constant VOTE_MULTIPLIER_COMMON_GEN0 = 100;
    uint8 internal constant VOTE_MULTIPLIER_COMMON_GEN1 = 99;
    uint8 internal constant VOTE_MULTIPLIER_COMMON_GEN2 = 98;

    uint8 internal constant VOTE_MULTIPLIER_RARE_GEN0 = 100;
    uint8 internal constant VOTE_MULTIPLIER_RARE_GEN1 = 98;
    uint8 internal constant VOTE_MULTIPLIER_RARE_GEN2 = 96;

    uint8 internal constant VOTE_MULTIPLIER_EPIC_GEN0 = 100;
    uint8 internal constant VOTE_MULTIPLIER_EPIC_GEN1 = 96;
    uint8 internal constant VOTE_MULTIPLIER_EPIC_GEN2 = 94;

    uint8 internal constant VOTE_MULTIPLIER_LEGENDARY_GEN0 = 100;
    uint8 internal constant VOTE_MULTIPLIER_LEGENDARY_GEN1 = 94;
    uint8 internal constant VOTE_MULTIPLIER_LEGENDARY_GEN2 = 92;

    mapping(uint256 => string) internal _names;
    mapping(uint256 => Level) internal _levels;

    constructor(
        string memory name_,
        string memory symbol_,
        address owner
    ) NFT(name_, symbol_, owner) {}

    function batchMint(address owner, string[] calldata names)
        external
        override
        isLootboxOrOwner
        returns (uint256[] memory tokenIds)
    {
        if (names.length > type(uint8).max) revert Overflow();
        uint256 length = names.length;

        tokenIds = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            if (bytes(names[i]).length == 0) revert EmptyName();

            tokenIds[i] = _mintAndSetRarityAndHashrate(owner);
            _names[tokenIds[i]] = names[i];
            emit NameSet(tokenIds[i], names[i]);
        }

        return tokenIds;
    }

    function updateLevel(uint256 tokenId, Level level) external override isOwner isExistingToken(tokenId) {
        if (_levels[tokenId] == level) revert SameValue();
        _levels[tokenId] = level;
        emit LevelUpdated(tokenId, level);
    }

    function getName(uint256 tokenId) external view override isExistingToken(tokenId) returns (string memory) {
        return _names[tokenId];
    }

    function getLevel(uint256 tokenId) external view override isExistingToken(tokenId) returns (Level) {
        return _levels[tokenId];
    }

    //solhint-disable code-complexity
    //solhint-disable function-max-lines
    function getHashrate(uint256 tokenId) external view override returns (uint256) {
        Level level = _levels[tokenId];
        Rarity rarity = _rarities[tokenId];
        uint256 baseHashrate = _baseHashrates[tokenId];

        if (rarity == Rarity.Common) {
            if (level == Level.Gen0) {
                return baseHashrate * HASHRATE_MULTIPLIERS_COMMON_GEN0;
            } else if (level == Level.Gen1) {
                return baseHashrate * HASHRATE_MULTIPLIERS_COMMON_GEN1;
            } else if (level == Level.Gen2) {
                return baseHashrate * HASHRATE_MULTIPLIERS_COMMON_GEN2;
            } else {
                revert WrongLevel();
            }
        } else if (rarity == Rarity.Rare) {
            if (level == Level.Gen0) {
                return baseHashrate * HASHRATE_MULTIPLIERS_RARE_GEN0;
            } else if (level == Level.Gen1) {
                return baseHashrate * HASHRATE_MULTIPLIERS_RARE_GEN1;
            } else if (level == Level.Gen2) {
                return baseHashrate * HASHRATE_MULTIPLIERS_RARE_GEN2;
            } else {
                revert WrongLevel();
            }
        } else if (rarity == Rarity.Epic) {
            if (level == Level.Gen0) {
                return baseHashrate * HASHRATE_MULTIPLIERS_EPIC_GEN0;
            } else if (level == Level.Gen1) {
                return baseHashrate * HASHRATE_MULTIPLIERS_EPIC_GEN1;
            } else if (level == Level.Gen2) {
                return baseHashrate * HASHRATE_MULTIPLIERS_EPIC_GEN2;
            } else {
                revert WrongLevel();
            }
        } else if (rarity == Rarity.Legendary) {
            if (level == Level.Gen0) {
                return baseHashrate * HASHRATE_MULTIPLIERS_LEGENDARY_GEN0;
            } else if (level == Level.Gen1) {
                return baseHashrate * HASHRATE_MULTIPLIERS_LEGENDARY_GEN1;
            } else if (level == Level.Gen2) {
                return baseHashrate * HASHRATE_MULTIPLIERS_LEGENDARY_GEN2;
            } else {
                revert WrongLevel();
            }
        } else {
            revert WrongRarity();
        }
    }

    function getVotePrice(uint256 tokenId) external view override isExistingToken(tokenId) returns (uint256) {
        Level level = _levels[tokenId];
        Rarity rarity = _rarities[tokenId];

        if (rarity == Rarity.Common) {
            if (level == Level.Gen0) {
                return (VOTE_PRICE * VOTE_MULTIPLIER_COMMON_GEN0) / 100;
            } else if (level == Level.Gen1) {
                return (VOTE_PRICE * VOTE_MULTIPLIER_COMMON_GEN1) / 100;
            } else if (level == Level.Gen2) {
                return (VOTE_PRICE * VOTE_MULTIPLIER_COMMON_GEN2) / 100;
            } else {
                revert WrongLevel();
            }
        } else if (rarity == Rarity.Rare) {
            if (level == Level.Gen0) {
                return (VOTE_PRICE * VOTE_MULTIPLIER_RARE_GEN0) / 100;
            } else if (level == Level.Gen1) {
                return (VOTE_PRICE * VOTE_MULTIPLIER_RARE_GEN1) / 100;
            } else if (level == Level.Gen2) {
                return (VOTE_PRICE * VOTE_MULTIPLIER_RARE_GEN2) / 100;
            } else {
                revert WrongLevel();
            }
        } else if (rarity == Rarity.Epic) {
            if (level == Level.Gen0) {
                return (VOTE_PRICE * VOTE_MULTIPLIER_EPIC_GEN0) / 100;
            } else if (level == Level.Gen1) {
                return (VOTE_PRICE * VOTE_MULTIPLIER_EPIC_GEN1) / 100;
            } else if (level == Level.Gen2) {
                return (VOTE_PRICE * VOTE_MULTIPLIER_EPIC_GEN2) / 100;
            } else {
                revert WrongLevel();
            }
        } else if (rarity == Rarity.Legendary) {
            if (level == Level.Gen0) {
                return (VOTE_PRICE * VOTE_MULTIPLIER_LEGENDARY_GEN0) / 100;
            } else if (level == Level.Gen1) {
                return (VOTE_PRICE * VOTE_MULTIPLIER_LEGENDARY_GEN1) / 100;
            } else if (level == Level.Gen2) {
                return (VOTE_PRICE * VOTE_MULTIPLIER_LEGENDARY_GEN2) / 100;
            } else {
                revert WrongLevel();
            }
        } else {
            revert WrongRarity();
        }
    }

    //solhint-enable code-complexity
    //solhint-enable function-max-lines
}
