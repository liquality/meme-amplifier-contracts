// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IPool} from "../interfaces/IPool.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Pool is IPool, Pausable, ReentrancyGuard  {

/* ======================= STORAGE ====================== */
    struct Participant {
        address id;
        uint64 contribution;
        uint256 rewardedAmountNative;
        uint256 rewardAvailableNative;
        uint256 rewardAvailableToken;
        uint256 rewardedAmountToken;
    }
    mapping(address => Participant) public participantData;
    
    address[] public participants;
    address immutable public  poolInitiator;
    address immutable public  collective;
    address immutable public  tokenContract;

    uint256 public rewardDistributionPercent; // percentage of pool reward to be distributed to creaors i.e 50% = division by 2
    uint256 public rewardDistributedNative; 
    uint256 public rewardDistributedToken; 
    uint128 public totalContributions;

    bool public isDistributed;    // flag to indicate if reward has been distributed
    bool public isRewardReceived; // flag to indicate if pool reward has been received


/* ======================= MODIFIERS ====================== */
    modifier onlyPoolInitiator() {
        require(msg.sender == poolInitiator, "Pool__Authorization:onlyPoolInitiator");
        _;
    }
    modifier onlyCollective() {
        require(msg.sender == collective, "Pool__Authorization:OnlyCollective");
        _;
    }

/* ======================= EXTERNAL METHODS ====================== */


    constructor(address _tokenContract, address _initiator) {
        tokenContract = _tokenContract;
        poolInitiator = _initiator;
        rewardDistributionPercent = 2;
        collective = msg.sender;
    }

    function pause() external onlyCollective {
        _pause();
    }

    function unpause() external onlyCollective {
        _unpause();
    }

    receive() external payable {
        if (msg.sender == collective) {
            isRewardReceived = true;
            emit RewardReceived(msg.sender, msg.value);
        }
    }

    // @inheritdoc IPool
    function recordMint(address _participant, uint256 _tokenID, uint256 _quantity, uint256 _amountPaid) 
    external onlyCollective whenNotPaused {
        participantData[_participant].contribution += uint64(_quantity);
        totalContributions += uint128(_quantity);

        if (participantData[_participant].id == address(0)) {
            participantData[_participant].id = _participant;
            participants.push(_participant);
        }

        emit NewMint(_participant, _tokenID, _quantity, _amountPaid);
    }

    // @inheritdoc IPool
    function distributeReward(address _tokenContract) external {
        uint256 poolRewardNative = address(this).balance / rewardDistributionPercent;
        uint256 poolRewardToken = _tokenContract != address(0) 
        ? IERC20(_tokenContract).balanceOf(address(this)) / rewardDistributionPercent 
        : 0;

        if (isDistributed || !isRewardReceived || (poolRewardNative == 0 && poolRewardToken == 0) || participants.length == 0) {
            revert Pool__NoRewardToDistribute();
        }
        for (uint256 i = 0; i < participants.length;) {
            uint256 contribution = participantData[participants[i]].contribution;

            participantData[participants[i]].rewardedAmountNative = 
                (contribution * poolRewardNative) / totalContributions;

            participantData[participants[i]].rewardAvailableNative = 
                participantData[participants[i]].rewardedAmountNative;
            // Token distribution
            if ( _tokenContract != address(0) && poolRewardToken > 0) {
                participantData[participants[i]].rewardedAmountToken = 
                    (contribution * poolRewardToken) / totalContributions;
                participantData[participants[i]].rewardAvailableToken = 
                    participantData[participants[i]].rewardedAmountToken;
            }
            unchecked {
                i++;
            }
        }
        isDistributed = true;
        emit RewardDistributed(poolRewardNative, poolRewardToken);
    }

    // @inheritdoc IPool
    function withdrawReward(address[] calldata _participants, address _tokenContracts) external nonReentrant {
        for (uint256 i = 0; i < _participants.length;) {
            address _participant = _participants[i];
            if (participantData[_participant].id != address(0)) {
                uint256 rewardAvailableNative = participantData[_participant].rewardAvailableNative;
                uint256 rewardAvailableToken = participantData[_participant].rewardAvailableToken;
                if (rewardAvailableNative != 0 || rewardAvailableToken != 0) {
                    // transfer token reward
                    participantData[_participant].rewardAvailableToken = 0;
                    bool success = IERC20(_tokenContracts).transfer(_participant, rewardAvailableToken);
                    if (!success) {
                        participantData[_participant].rewardAvailableToken = rewardAvailableToken;
                    } else {
                        rewardDistributedToken += rewardAvailableToken;
                        emit RewardWithdrawn(_participant, 0, rewardAvailableToken);
                    }
                    // transfer native reward
                    participantData[_participant].rewardAvailableNative = 0;
                    (success, ) = payable(_participant).call{value: rewardAvailableNative}("");
                    if (!success) {
                        participantData[_participant].rewardAvailableNative = rewardAvailableNative;
                    } else {
                        rewardDistributedNative += rewardAvailableNative;
                        emit RewardWithdrawn(_participant, rewardAvailableNative, 0);
                    }
                }
            }

            unchecked {
                i++;
            }
        }
    }

    // withdraw all funds from the pool to recipient
    function withdrawNative(address payable _recipient) external nonReentrant onlyPoolInitiator {
        (bool success, ) = payable(_recipient).call{value: address(this).balance}("");
        if (!success) {
            revert Pool__FailedToWithdrawFunds(_recipient, address(0), address(this).balance);
        }
        emit WithdrawnFromPool(_recipient, address(0), address(this).balance);
    }

    // withdraw all ERC20 tokens from the pool to recipient
    function withdrawERC20(address _tokenContract, address _recipient) external nonReentrant onlyPoolInitiator {
        uint256 balance = IERC20(_tokenContract).balanceOf(address(this));
        bool success = IERC20(_tokenContract).transfer(_recipient, balance);
        if (!success) {
            revert Pool__FailedToWithdrawFunds(_recipient, _tokenContract, balance);
        }
        emit WithdrawnFromPool(_recipient, _tokenContract, balance);
    }

    function setDistributionPercent(uint256 _percent) external onlyPoolInitiator {
        require(_percent > 0, "Pool__InvalidPercent");
        rewardDistributionPercent = _percent;
    } 

/* ======================= READ ONLY METHODS ====================== */

    // @inheritdoc IPool
     function getParticipantsCount() public view returns (uint256) {
        return participants.length;
     }

    // @inheritdoc IPool
    function getPoolInfo() public view returns 
    (address _tokenContract, uint256 _rewardDistributedNative, uint256 _rewardDistributedToken, uint256 _totalContributions, bool _isRewardReceived, bool _isDistributed) {
        return (tokenContract, rewardDistributedNative, rewardDistributedToken, totalContributions, isRewardReceived, isDistributed);
    }

    // @inheritdoc IPool
    function isPoolActive() public view returns (bool) {
        return paused();
    }

    // getParticipants
    function getParticipants() public view returns (address[] memory) {
        return participants;
    }
       
}