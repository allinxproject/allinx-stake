/**
 *Submitted for verification at Etherscan.io on 2020-09-16
*/

pragma solidity ^0.5.16;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./UniswapReward.sol";
import "../library/Governance.sol";

interface IMinterV2ERC20 {
    function mint(address dst, uint rawAmount) external;
}

contract StakingRewardsFactory is Governance {
    using SafeMath for uint;
    // immutables
    address public rewardsToken;
    address public govRewardAccount;
    uint public stakingAmountGenesis=2918271e18;
    uint public stakingAmountTotal=350_000_000e18;
    uint public stakingRewardsGenesis;
    uint public periodRate=9990;
    uint public baseRate=10000;
    uint public periodNum=0;

    // the staking tokens for which the rewards contract has been deployed
    address[] public stakingTokens;

    uint public rewardRateTotal=0;

    // info about rewards for a particular staking token
    struct StakingRewardsInfo {
        address stakingRewards;
        uint rewardRate;
    }

    // rewards info by staking token
    mapping(address => StakingRewardsInfo) public stakingRewardsInfoByStakingToken;

    constructor(
        address _rewardsToken,
        address _govRewardAccount,
        uint _stakingRewardsGenesis
    ) Governance() public {
        require(_stakingRewardsGenesis >= block.timestamp, 'StakingRewardsFactory::constructor: genesis too soon');

        rewardsToken = _rewardsToken;
        govRewardAccount = _govRewardAccount;
        stakingRewardsGenesis = _stakingRewardsGenesis;
    }

    ///// permissioned functions

    // deploy a staking reward contract for the staking token, and store the reward amount
    // the reward will be distributed to the staking reward contract no sooner than the genesis
    function deploy(address[] memory _stakingTokens, uint[] memory _rewardRates) public onlyGovernance {
        require(_stakingTokens.length == _rewardRates.length, "stakingTokens and rewardRates lengths mismatch");

        for (uint i = 0; i < _rewardRates.length; i++) {
            require(_stakingTokens[i] != address(0), "StakingRewardsFactory::deploy: stakingToken empty");

            StakingRewardsInfo storage  info = stakingRewardsInfoByStakingToken[_stakingTokens[i]];

            rewardRateTotal = rewardRateTotal.sub(info.rewardRate).add(_rewardRates[i]);
            info.rewardRate = _rewardRates[i];

            if(info.stakingRewards == address(0)){
                info.stakingRewards = address(new UniswapReward(
                    /*rewardsDistribution_=*/ address(this),
                    /*token_=*/     rewardsToken,
                    /*lpToken_=*/     _stakingTokens[i]
                    ));
                stakingTokens.push(_stakingTokens[i]);
            }
        }
    }

    function setStakingRate(address stakingToken,uint rewardRate) public onlyGovernance {
        StakingRewardsInfo storage info = stakingRewardsInfoByStakingToken[stakingToken];
        require(info.stakingRewards != address(0), 'StakingRewardsFactory::setStakingEnabled: not deployed');

        rewardRateTotal = rewardRateTotal.sub(info.rewardRate).add(rewardRate);
        info.rewardRate = rewardRate;
    }

    ///// permissionless functions
    function getPeriodRewardAmount() internal returns (uint){
        uint periodReward = stakingAmountGenesis;
        if(stakingAmountGenesis >= stakingAmountTotal){
            return stakingAmountTotal;
        }
        if(periodNum == 0){
            return periodReward;
        }
        if(periodNum == 12){
            periodReward = 1753414e18;
        }else if(periodNum == 52){
            periodReward = 1732834e18;
            periodRate = 9960;
        }else{
            periodReward = periodReward.mul(periodRate).div(baseRate);
        }
        return periodReward;
    }

    // call notifyRewardAmount for all staking tokens.
    function notifyRewardAmounts() public onlyGovernance{
        require(stakingTokens.length > 0, 'StakingRewardsFactory::notifyRewardAmounts: called before any deploys');
        require(block.timestamp >= stakingRewardsGenesis, 'StakingRewardsFactory::notifyRewardAmounts: reward not start');
        require(stakingAmountTotal > 0, 'StakingRewardsFactory::notifyRewardAmounts: reward is over');

        stakingAmountGenesis = getPeriodRewardAmount();
        stakingRewardsGenesis = stakingRewardsGenesis + 7 days;
        stakingAmountTotal = stakingAmountTotal.sub(stakingAmountGenesis);
        periodNum++;

        _mint(stakingAmountGenesis);

        uint _govFundAmount = stakingAmountGenesis.mul(5).div(100);// 5%
        _reserveRewards(govRewardAccount,_govFundAmount);

        uint _poolRewardAmount = stakingAmountGenesis.sub(_govFundAmount); // 95%
        _notifyPoolRewardAmounts(_poolRewardAmount);
    }

    function _notifyPoolRewardAmounts(uint _poolRewardAmount) private {
        uint _surplusRewardAmount = _poolRewardAmount;
        uint _rewardAmount = 0;
        address farmAddr;

        for (uint i = 0; i < stakingTokens.length; i++) {
            StakingRewardsInfo memory info = stakingRewardsInfoByStakingToken[stakingTokens[i]];
            if(info.rewardRate <= 0){
                continue;
            }
            if(stakingTokens[i] == rewardsToken){
                farmAddr = info.stakingRewards;
                continue;
            }
            _rewardAmount = _poolRewardAmount.mul(info.rewardRate).div(rewardRateTotal);
            if(_rewardAmount >= _surplusRewardAmount){
                _rewardAmount = _surplusRewardAmount;
            }
            _surplusRewardAmount = _surplusRewardAmount.sub(_rewardAmount);
            _notifyRewardAmount(info.stakingRewards,_rewardAmount);
        }
        _surplusRewardAmount = IERC20(rewardsToken).balanceOf(address(this));
        if(_surplusRewardAmount > 0 && farmAddr != address(0)){
            _notifyRewardAmount(farmAddr,_surplusRewardAmount);
        }
    }


    // notify reward amount for an individual staking token.
    // this is a fallback in case the notifyRewardAmounts costs too much gas to call for all contracts
    function _notifyRewardAmount(address _stakingToken,uint _rewardAmount) private {
        require(_stakingToken != address(0), 'StakingRewardsFactory::notifyRewardAmount: not deployed');

        if (_rewardAmount > 0) {
            require(
                IERC20(rewardsToken).transfer(_stakingToken, _rewardAmount),
                'StakingRewardsFactory::notifyRewardAmount: transfer failed'
            );
            UniswapReward(_stakingToken).notifyRewardAmount(_rewardAmount);
        }
    }

    function _reserveRewards(address _account,uint _rawRewardsAmount) private {
        require(_account != address(0), 'StakingRewardsFactory::_reserveRewards: not deployed');

        require(
            IERC20(rewardsToken).transfer(_account, _rawRewardsAmount),
            'StakingRewardsFactory::_reserveRewards: transfer failed'
        );
    }

    function _mint(uint _mintAmount) private {
        require(_mintAmount > 0, 'StakingRewardsFactory::_mint: mintAmount is zero');

        IMinterV2ERC20(rewardsToken).mint(address(this), _mintAmount);
    }
}