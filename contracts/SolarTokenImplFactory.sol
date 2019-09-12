pragma solidity ^0.4.24;

import "./SolarTokenImpl.sol";

contract SolarTokenImplFactory {
    function newImpl(
        address _tokenProxyAddr,
        string _version,
        uint256 _chainId
    ) public returns (address) {
        return new SolarTokenImpl(_tokenProxyAddr, _version, _chainId);
    }
}
