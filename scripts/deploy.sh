echo "deploy begin....."

mkdir -p ./deployments

TF_CMD=node_modules/.bin/truffle-flattener

#echo "" >  ./deployments/UniswapReward.full.sol
#cat  ./scripts/head.sol >  ./deployments/UniswapReward.full.sol
#$TF_CMD ./contracts/reward/UniswapReward.sol >>  ./deployments/UniswapReward.full.sol


echo "" >  ./deployments/PlayerBook.full.sol
cat  ./scripts/head.sol >  ./deployments/PlayerBook.full.sol
$TF_CMD ./contracts/referral/PlayerBook.sol >>  ./deployments/PlayerBook.full.sol 


echo "" >  ./deployments/LPTestERC20.full.sol
cat  ./scripts/head.sol >  ./deployments/LPTestERC20.full.sol
$TF_CMD ./contracts/test/LPTestERC20.sol >>  ./deployments/LPTestERC20.full.sol 

echo "" >  ./deployments/TestMSG.full.sol
cat  ./scripts/head.sol >  ./deployments/TestMSG.full.sol
$TF_CMD ./contracts/test/TestMSG.sol >>  ./deployments/TestMSG.full.sol 


echo "" >  ./deployments/TestArray.full.sol
cat  ./scripts/head.sol >  ./deployments/TestArray.full.sol
$TF_CMD ./contracts/test/TestArray.sol >>  ./deployments/TestArray.full.sol 


echo "" >  ./deployments/SegmentPowerStrategy.full.sol
cat  ./scripts/head.sol >  ./deployments/SegmentPowerStrategy.full.sol
$TF_CMD ./contracts/library/SegmentPowerStrategy.sol >>  ./deployments/SegmentPowerStrategy.full.sol 


echo "" >  ./deployments/AutoIDOFactory.full.sol
cat  ./scripts/head.sol >  ./deployments/AutoIDOFactory.full.sol
$TF_CMD ./contracts/onekey/AutoIDOFactory.sol >>  ./deployments/AutoIDOFactory.full.sol


#echo "" >  ./deployments/IDOERC20.full.sol
#cat  ./scripts/head.sol >  ./deployments/IDOERC20.full.sol
#$TF_CMD ./contracts/onekey/IDOERC20.sol >>  ./deployments/IDOERC20.full.sol


echo "" >  ./deployments/StakingRewardsFactory.full.sol
cat  ./scripts/head.sol >  ./deployments/StakingRewardsFactory.full.sol
$TF_CMD ./contracts/reward/StakingRewardsFactory.sol >>  ./deployments/StakingRewardsFactory.full.sol


echo "" >  ./deployments/IDOStakingRewardsFactory.full.sol
cat  ./scripts/head.sol >  ./deployments/IDOStakingRewardsFactory.full.sol
$TF_CMD ./contracts/reward/IDOStakingRewardsFactory.sol >>  ./deployments/IDOStakingRewardsFactory.full.sol


echo "" >  ./deployments/Inx.full.sol
cat  ./scripts/head.sol >  ./deployments/Inx.full.sol
$TF_CMD ./contracts/token/Inx.sol >>  ./deployments/Inx.full.sol


echo "" >  ./deployments/AutoStake.full.sol
cat  ./scripts/head.sol >  ./deployments/AutoStake.full.sol
$TF_CMD ./contracts/reward/AutoStake.sol >>  ./deployments/AutoStake.full.sol


echo "" >  ./deployments/RedeliveryMachineReward.full.sol
cat  ./scripts/head.sol >  ./deployments/RedeliveryMachineReward.full.sol
$TF_CMD ./contracts/reward/RedeliveryMachineReward.sol >>  ./deployments/RedeliveryMachineReward.full.sol

echo "deploy end....."