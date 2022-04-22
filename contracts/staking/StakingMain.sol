// SPDX-License-Identifier: Apache 2.0
// Copyright © 2022 Artem Belozerov. All rights reserved.
pragma solidity ^0.8.0;

import "./StakingMain.sol";
import "./interfaces/IStakingMain.sol";
import "./interfaces/IStakingEvents.sol";
import "./common/StakingConstants.sol";
import "./common/StakingErrors.sol";
import "./common/StakingStorage.sol";
import "../common/ownership/Ownable.sol";
import "../common/interfaces/IERC20.sol";
import "../voucher/interfaces/IVoucher.sol";

contract StakingMain is IStakingMain, IStakingEvents, Ownable, StakingStorage {
    function stakeVotes(uint256 votesNumber) external override {
        uint256 remainder = votesNumber - (votesNumber / StakingConstants.STAKE_STEP) * StakingConstants.STAKE_STEP;
        if (votesNumber < StakingConstants.STAKE_STEP || remainder != 0) revert StakingErrors.WrongMultiplicity();

        // the first stake must be more then the threshold
        Stake[] storage stakes = _stakes[msg.sender];
        if (stakes.length == 0 && votesNumber < _votesThreshold) revert StakingErrors.NotEnoughVotesForStake();

        // check delay between stakes
        if (stakes.length != 0) {
            Stake memory lastStake = stakes[stakes.length - 1];
            if (lastStake.startDate > block.timestamp) revert StakingErrors.StakeDateBeforeNow();

            uint256 timeDelta = block.timestamp - lastStake.startDate;
            if (timeDelta < StakingConstants.STAKE_COOLDOWN) revert StakingErrors.TooOftenStaking();
        }

        // check staker balance
        uint256 votesBalance = IERC20(_config.voteAddress).balanceOf(msg.sender);
        if (votesBalance < votesNumber) revert StakingErrors.NotEnoughVotes();

        // append a new stake
        _pushStake(msg.sender, block.timestamp, votesNumber);

        // TODO: change IERC20 to IVote
        IERC20(_config.voteAddress).transferFrom(msg.sender, address(this), votesNumber);
        emit VotesStaked(block.timestamp, votesNumber);
    }

    function unstakeVotes() external override {
        Stake[] storage stakes = _stakes[msg.sender];
        if (stakes.length == 0) revert StakingErrors.StakerNotFound();

        // remove stakes
        uint256 vouchersNumber;
        uint256 votesNumber;
        while (stakes.length > 0) {
            Stake memory stake = stakes[stakes.length - 1];
            vouchersNumber += _calculateVouchers(stake);
            votesNumber += stake.amount;

            _popStake(msg.sender);
        }

        // ???
        uint256 votesBalance = IERC20(_config.voteAddress).balanceOf(address(this));
        if (votesBalance < votesNumber) revert StakingErrors.NotEnoughVotes();

        IERC20(_config.voteAddress).transfer(msg.sender, votesNumber);
        emit VotesUnstaked(msg.sender, votesNumber);

        if (vouchersNumber == 0) return;

        IVoucher(_config.voucherAddress).mint(msg.sender, vouchersNumber);
        emit VouchersMinted(msg.sender, vouchersNumber);
    }

    function withdrawVouchersForAll() external override isOwner {
        for (uint256 i = 0; i < _stakers.length; i++) {
            withdrawVouchers(_stakers[i]);
        }
    }

    function setThreshold(uint256 threshold) external override isOwner {
        _votesThreshold = threshold;
    }

    function getThreshold() external view override returns (uint256) {
        return _votesThreshold;
    }

    function getVotesAmount() external view override returns (uint256) {
        Stake[] memory stakes = _stakes[msg.sender];
        if (stakes.length == 0) revert StakingErrors.StakerNotFound();

        uint256 voteNumber;
        for (uint256 i = 0; i < stakes.length; i++) {
            voteNumber += stakes[i].amount;
        }
        return voteNumber;
    }

    function getVouchersAmount() external view override returns (uint256) {
        Stake[] memory stakes = _stakes[msg.sender];
        if (stakes.length == 0) revert StakingErrors.StakerNotFound();

        uint256 vouchersNumber;
        for (uint256 i = 0; i < stakes.length; i++) {
            vouchersNumber += _calculateVouchers(stakes[i]);
        }
        return vouchersNumber;
    }

    // TODO: during withdrawal we should merge multiple stakes to the only one. it will free storage
    function withdrawVouchers(address staker) public override isOwner {
        Stake[] storage stakes = _stakes[staker];
        if (stakes.length == 0) revert StakingErrors.StakerNotFound();

        uint256 vouchersNumber;
        for (uint256 i = 0; i < stakes.length; i++) {
            vouchersNumber += _calculateVouchers(stakes[i]);

            // reset staking time
            stakes[i].startDate = block.timestamp;
        }

        if (vouchersNumber == 0) return;

        IVoucher(_config.voucherAddress).mint(staker, vouchersNumber);
        emit VouchersMinted(staker, vouchersNumber);
    }

    function _pushStake(
        address staker,
        uint256 startDate,
        uint256 amount
    ) internal {
        // add staker
        if (_stakes[staker].length == 0) {
            _stakers.push(staker);
            emit StakerAdded(staker);
        }

        // add stake
        Stake memory stake = Stake({ startDate: startDate, amount: amount });
        _stakes[staker].push(stake);
        emit StakeAdded(staker, startDate, amount);
    }

    function _popStake(address staker) private {
        // remove a stake
        Stake memory stake = _stakes[staker][_stakes[staker].length - 1];
        _stakes[staker].pop();
        emit StakeRemoved(msg.sender, stake.startDate, stake.amount);

        // remove a staker
        if (_stakes[staker].length == 0) {
            delete _stakes[staker];

            for (uint256 i = 0; i < _stakers.length; i++) {
                if (_stakers[i] == msg.sender) {
                    _stakers[i] = _stakers[_stakers.length - 1];
                    _stakers.pop();
                    emit StakerRemoved(staker);
                    break;
                }
            }
        }
    }

    function _calculateVouchers(Stake memory stake) private view returns (uint256) {
        if (stake.startDate > block.timestamp) revert StakingErrors.StakeDateBeforeNow();

        // rounding to whole hours: 10:45 -> 10:00
        uint256 delta = ((block.timestamp - stake.startDate) / 1 hours) * 1 hours;
        uint256 voucherDecimal = 2;
        uint256 precision = 3;

        uint256 votesRatio = (stake.amount * 10**(voucherDecimal + precision)) / StakingConstants.VOTES_PER_VOUCHER;
        uint256 timesRatio = (delta * 10**(voucherDecimal + precision)) / StakingConstants.SECONDS_PER_VOUCHER;
        uint256 result = (votesRatio * timesRatio) / 10**(voucherDecimal + precision * 2);
        return result;
    }
}
