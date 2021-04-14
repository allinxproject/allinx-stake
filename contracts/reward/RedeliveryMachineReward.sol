pragma solidity ^0.5.0;


import "../interface/IUniswapV2Router02.sol";
import "../interface/IAutoIDOFactory.sol";
import "../interface/IERC20.sol";
import "../library/Governance.sol";

contract RedeliveryMachineReward is Governance {

    IUniswapV2Router02 public router = IUniswapV2Router02(0x70756620ab567B57335f29d372297a0832ea462C);
    IAutoIDOFactory public idoFactory;

    IERC20  public claimCostToken = IERC20(0x55d398326f99059fF775485246999027B3197955);//usdt token
    IERC20  public inxToken = IERC20(0x75b026Cc75cD2cE3DeF282f083b5F249e8A85DE2);//inx token

    address public burnWallet = 0x6666666666666666666666666666666666666666;

    event Redelivery(address indexed burnToken, address indexed tokenB, address indexed lpToken, uint256 lpAmount, uint256 burnAmount);
    event InxRedelivery(address indexed burnToken, address indexed costToken, uint256 burnAmount, uint256 costAmount);

    constructor() Governance() public {
    }

    function tokensByInfo(address tokenA) external view returns (string memory symbol,address pool,address pair,address tokenB){
        return idoFactory.factoryTokensByInfo(tokenA);
    }

    function redelivery(address burnToken) external {
        (,,address lpToken,address tokenB) = this.tokensByInfo(burnToken);
        require(lpToken != address(0),"redelivery lpToken is empty");
        require(tokenB != address(0),"redelivery tokenB is empty");

        uint lpAmount = IERC20(lpToken).balanceOf(address(this));
        require(lpAmount > 0,"redelivery lpAmount > 0");

        if( IERC20(lpToken).allowance(address(this),address(router)) < lpAmount ){
            IERC20(lpToken).approve(address(router),uint(-1));
        }
        router.removeLiquidity(burnToken,tokenB,lpAmount,0,0,address(this),now+1800);

        address[] memory swap2TokenRouting = new address[](2);// swap tokenB to burnToken
        swap2TokenRouting[0] = tokenB;
        swap2TokenRouting[1] = burnToken;

        uint tokenBAmount = IERC20(tokenB).balanceOf(address(this));
        if( IERC20(tokenB).allowance(address(this),address(router)) < tokenBAmount ){
            IERC20(tokenB).approve(address(router),uint(-1));
        }
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            /* uint amountIn */tokenBAmount,
            /* uint amountOutMin */0,
            /* address[] calldata path */swap2TokenRouting,
            /* address to */address(this),
            /* uint deadline */now+1800
        );

        uint burnAmount = IERC20(burnToken).balanceOf(address(this));
        require(
            IERC20(burnToken).transfer(burnWallet, burnAmount),
            'burnToken transfer failed'
        );

        emit Redelivery(burnToken, tokenB, lpToken, lpAmount, burnAmount);
    }

    function inxRedelivery() external onlyGovernance {
        address[] memory swap2TokenRouting = new address[](2);// swap usdt to inx
        swap2TokenRouting[0] = address(claimCostToken);
        swap2TokenRouting[1] = address(inxToken);

        uint costAmount = claimCostToken.balanceOf(address(this));
        if( claimCostToken.allowance(address(this),address(router)) < costAmount ){
            claimCostToken.approve(address(router),uint(-1));
        }
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
        /* uint amountIn */costAmount,
        /* uint amountOutMin */0,
        /* address[] calldata path */swap2TokenRouting,
        /* address to */address(this),
        /* uint deadline */now+1800
        );

        uint burnAmount = IERC20(inxToken).balanceOf(address(this));
        require(
            IERC20(inxToken).transfer(burnWallet, burnAmount),
            'burnToken transfer failed'
        );

        emit InxRedelivery(address(inxToken), address(claimCostToken), burnAmount,costAmount);
    }

    function setRouter(address _router) external onlyGovernance {
        router = IUniswapV2Router02(_router);
    }

    function setIdoFactory(address _idoFactory) external onlyGovernance {
        idoFactory = IAutoIDOFactory(_idoFactory);
    }

    function setClaimCostToken(address _claimCostToken) external onlyGovernance {
        claimCostToken = IERC20(_claimCostToken);
    }

    function setInxToken(address _inxToken) external onlyGovernance {
        inxToken = IERC20(_inxToken);
    }
}