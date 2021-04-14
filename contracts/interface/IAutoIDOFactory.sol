pragma solidity ^0.5.0;


interface IAutoIDOFactory {
    function factoryTokensByInfo(address tokenA) external view returns (string memory symbol,address pool,address pair,address tokenB);
}
