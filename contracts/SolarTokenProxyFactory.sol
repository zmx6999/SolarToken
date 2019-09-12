pragma solidity ^0.4.24;

import "./SolarTokenProxy.sol";

contract SolarTokenProxyFactory {
    function newProxy(
        address _creator,
        string _name,
        string _symbol,
        uint256 _decimals,
        address _votingFactoryAddr
    ) public view returns (address) {
        return new SolarTokenProxy(_creator, _name, _symbol, _decimals, _votingFactoryAddr);
    }
}
