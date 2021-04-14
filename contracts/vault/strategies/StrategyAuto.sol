// SPDX-License-Identifier: MIT

pragma solidity ^0.5.15;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function decimals() external view returns (uint);
    function name() external view returns (string memory);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;

        return c;
    }
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

library Address {
    function isContract(address account) internal view returns (bool) {
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly { codehash := extcodehash(account) }
        return (codehash != 0x0 && codehash != accountHash);
    }
    function toPayable(address account) internal pure returns (address payable) {
        return address(uint160(account));
    }
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        // solhint-disable-next-line avoid-call-value
        (bool success, ) = recipient.call.value(amount)("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }
}

library SafeERC20 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }
    function callOptionalReturn(IERC20 token, bytes memory data) private {
        require(address(token).isContract(), "SafeERC20: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");

        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

interface Controller {
    function vaults(address) external view returns (address);
    function rewards() external view returns (address);
}

interface AutoFarmV2 {
    function deposit(uint256 _pid, uint256 _wantAmt) external;
	function withdraw(uint256 _pid, uint256 _wantAmt) external;
	function withdrawAll(uint256 _pid) external;
	function stakedWantTokens(uint256 _pid, address _user)
        external
        view
        returns (uint256);
	function pendingAUTO(uint256 _pid, address _user)
        external
        view
        returns (uint256);
}

interface PancakeRouter {
	function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

contract StrategyAuto {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

	uint256 public pid = 2;

    address constant public pancakeRouter = address(0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F);
    address constant public inxrouter = address(0x70756620ab567B57335f29d372297a0832ea462C);
    address constant public inx = address(0xd60D91EAE3E0F46098789fb593C06003253E5D0a);
	address constant public wbnb = address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    address constant public usdt = address(0x55d398326f99059fF775485246999027B3197955);

    address public want = address(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);  //BUSD

    address constant public autoFarm = address(0x0895196562C7868C5Be92459FaE7f877ED450452);  //AutoFarmV2
    address constant public AUTOv2 = address(0xa184088a740c695E156F91f5cC086a06bb78b827);    

    address public governance;
    address public controller;

    uint256 public redeliverynum = 1 * 1e18;
    uint256 public redeliveryRate = 60;

	address[] public swap2TokenRouting;
    address[] public swap2WantRouting;
    address[] public swap2INXRouting;

    modifier onlyController {
        require(msg.sender == controller, "!controller");
        _;
    }

	modifier isAuthorized() {
        require(msg.sender == governance || msg.sender == controller || msg.sender == address(this), "!authorized");
        _;
    }

    constructor(uint256 _pid,address _want) public {
		pid = _pid;
		want = _want;
        governance = tx.origin;
        controller = 0xb06baDE8d55e0be6E235674527299b73dCdE1552;
        doApprove();
		swap2WantRouting = [AUTOv2,wbnb,want];
        swap2TokenRouting = [AUTOv2,wbnb,usdt];
        swap2INXRouting = [usdt,inx];
    }

	function doApprove () internal{
        IERC20(AUTOv2).approve(pancakeRouter, uint(-1));
        IERC20(usdt).approve(inxrouter, uint(-1));
    }
	
	function setSwapRouting(uint _index,address[] memory _routing)public {
		require(msg.sender == governance, "!governance");
		if(_index==0){
			swap2WantRouting = _routing;
		}else if(_index==1){
			swap2TokenRouting = _routing;
		} else {
            swap2INXRouting = _routing;
            IERC20(_routing[0]).approve(inxrouter, uint(-1));
        }
	}

    function deposit() public isAuthorized{
		uint256 _wantAmount = IERC20(want).balanceOf(address(this));
		if (_wantAmount > 0) {
            IERC20(want).safeApprove(autoFarm, 0);
            IERC20(want).safeApprove(autoFarm, _wantAmount);

            AutoFarmV2(autoFarm).deposit(pid,_wantAmount);
        }
    }


    // Withdraw partial funds, normally used with a vault withdrawal
	function withdraw(uint _amount) external onlyController
	{
		uint amount = _withdraw(_amount);
		address _vault = Controller(controller).vaults(address(want));
        require(_vault != address(0), "!vault");
        IERC20(want).safeTransfer(_vault, amount);
	}


    function _withdraw(uint _amount) internal returns(uint) {
		uint amount = IERC20(want).balanceOf(address(this));
		if (amount < _amount) {
			AutoFarmV2(autoFarm).withdraw(pid,_amount.sub(amount));
			amount = IERC20(want).balanceOf(address(this));
            if (amount < _amount){
                return amount;
            }
        }
		return _amount;
    }

	function withdrawAll() external onlyController returns (uint balance){
		balance = _withdraw(balanceOf());

		address _vault = Controller(controller).vaults(address(want));
        require(_vault != address(0), "!vault");
        IERC20(want).safeTransfer(_vault, balance);
	}

    function balanceOfwant() public view returns (uint256) {
		return IERC20(want).balanceOf(address(this));
	}

	function balanceOfAutoFarm() public view returns (uint256) {
		return AutoFarmV2(autoFarm).stakedWantTokens(pid,address(this));
	}

    function balanceOf() public view returns (uint256) {
        return balanceOfwant().add(balanceOfAutoFarm());
    }
	
	function getPending() public view returns (uint256) {
        return AutoFarmV2(autoFarm).pendingAUTO(pid,address(this));
    }

	function getAUTOv2() public view returns(uint256)
	{
		return IERC20(AUTOv2).balanceOf(address(this));
	}

    function harvest() public
    {
        AutoFarmV2(autoFarm).withdraw(pid, 0);
        redelivery();
    }

    function redelivery() internal{
        uint256 reward = IERC20(AUTOv2).balanceOf(address(this));
        if (reward > redeliverynum){
            uint256 _2want = reward.mul(redeliveryRate).div(100);
            uint256 _2token = reward.sub(_2want);
            PancakeRouter(pancakeRouter).swapExactTokensForTokens(_2want, 0, swap2WantRouting, address(this), now.add(1800));
            address token = swap2TokenRouting[swap2TokenRouting.length-1];
            uint256 _before = IERC20(token).balanceOf(address(this));
            PancakeRouter(pancakeRouter).swapExactTokensForTokens(_2token, 0, swap2TokenRouting, address(this), now.add(1800));
            uint256 _after = IERC20(token).balanceOf(address(this));
            uint256 _2inx = _after.sub(_before);
            PancakeRouter(inxrouter).swapExactTokensForTokens(_2inx, 0, swap2INXRouting, Controller(controller).rewards(), now.add(1800));

            deposit();
        }
    }

    function setredeliverynum(uint256 value) public {
        require(msg.sender == governance, "!governance");
        redeliverynum = value;
    }

    function setredeliveryRate(uint256 value) public {
        require(msg.sender == governance, "!governance");
        require(value < 100 && value > 0, "redelivery rate error");
        redeliveryRate = value;
    }

    function setGovernance(address _governance) public {
        require(msg.sender == governance, "!governance");
        governance = _governance;
    }

    function setController(address _controller) external {
        require(msg.sender == governance, "!governance");
        controller = _controller;
    }
}