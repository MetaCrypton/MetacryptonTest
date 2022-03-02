// SPDX-License-Identifier: Apache 2.0
// Copyright © 2021 Anton "BaldyAsh" Grigorev. All rights reserved.
pragma solidity ^0.8.0;

import "../common/erc20/ERC20.sol";
import "./InventoryConfiguration.sol";
import "./InventoryAssetsSet.sol";
import "./InventoryErrors.sol";
import "./InventoryEther.sol";
import "./interfaces/IInventory.sol";

contract InventoryERC20 is IInventoryERC20, IInventoryEvents, InventoryEther {
    using InventoryAssetsSet for *;

    modifier verifyERC20Input(address token, uint256 amount) {
        if (token == address(0x00)) revert InventoryErrors.EmptyAddress();
        if (amount == 0) revert InventoryErrors.ZeroAmount();
        _;
    }

    constructor(InventoryConfig memory config, address owner) InventoryEther(config, owner) {}

    function depositERC20(
        address from,
        address token,
        uint256 amount
    ) external override isOwner verifyERC20Input(token, amount) {
        emit DepositERC20(from, token, amount);

        uint256 id = _getERC20Id(token);
        uint256 index = _assetsSet._getAssetIndexById(id);

        if (index == 0) {
            bytes memory data = abi.encode(ERC20Struct(token, amount));

            emit AssetAdded(id, AssetType.ERC20, data);
            _assetsSet._addAsset(id, AssetType.ERC20, data);
        } else {
            Asset storage asset = _assetsSet._getAssetByIndex(index);
            ERC20Struct memory storedToken = _assetToERC20Token(asset);
            if (storedToken.tokenAddress != token) revert InventoryErrors.UnmatchingTokenAddress();
            if (type(uint256).max - storedToken.amount < amount) revert InventoryErrors.DepositOverflow();
            storedToken.amount += amount;

            bytes memory data = abi.encode(storedToken);
            emit AssetUpdated(id, data);
            asset._updateAsset(data);
        }

        IERC20(token).transferFrom(from, address(this), amount);
    }

    function withdrawERC20(
        address recipient,
        address token,
        uint256 amount
    ) external override isOwner verifyERC20Input(token, amount) {
        emit WithdrawERC20(recipient, token, amount);

        uint256 id = _getERC20Id(token);
        uint256 index = _assetsSet._getAssetIndexById(id);
        if (index == 0) revert InventoryErrors.UnexistingAsset();

        Asset storage asset = _assetsSet._getAssetByIndex(index);
        ERC20Struct memory storedToken = _assetToERC20Token(asset);
        if (storedToken.tokenAddress != token) revert InventoryErrors.UnmatchingTokenAddress();
        if (storedToken.amount < amount) revert InventoryErrors.WithdrawOverflow();

        storedToken.amount -= amount;
        if (storedToken.amount > 0) {
            bytes memory data = abi.encode(storedToken);
            emit AssetUpdated(id, data);
            asset._updateAsset(data);
        } else {
            emit AssetRemoved(id);
            _assetsSet._removeAsset(index);
        }

        IERC20(token).transfer(recipient, amount);
    }

    function getERC20s(uint256 startIndex, uint256 number) external view override returns (ERC20Struct[] memory) {
        return _assetsSetListToERC20(_assetsSet._getAssets(startIndex, number));
    }

    function getERC20Balance(address token) external view override returns (uint256) {
        uint256 id = _getERC20Id(token);
        uint256 index = _assetsSet._getAssetIndexById(id);
        if (index == 0) revert InventoryErrors.UnexistingAsset();

        Asset storage asset = _assetsSet._getAssetByIndex(index);
        ERC20Struct memory storedToken = _assetToERC20Token(asset);
        if (storedToken.tokenAddress != token) revert InventoryErrors.UnmatchingTokenAddress();

        return storedToken.amount;
    }

    function _assetToERC20Token(Asset memory asset) internal pure returns (ERC20Struct memory) {
        if (asset.assetType != AssetType.ERC20) revert InventoryErrors.UnmatchingAssetType();

        return abi.decode(asset.data, (ERC20Struct));
    }

    function _assetsSetListToERC20(Asset[] memory assets) internal pure returns (ERC20Struct[] memory) {
        uint256 tokensLength = 0;
        uint256 assetsLength = assets.length;

        for (uint256 i = 0; i < assetsLength; i++) {
            if (assets[i].assetType == AssetType.ERC20) {
                tokensLength++;
            }
        }

        ERC20Struct[] memory tokens = new ERC20Struct[](tokensLength);
        uint256 counter = 0;
        for (uint256 i = 0; i < assetsLength; i++) {
            if (assets[i].assetType == AssetType.ERC20) {
                tokens[counter++] = _assetToERC20Token(assets[i]);
            }
        }

        return tokens;
    }

    function _getERC20Id(address token) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(token)));
    }
}
