pragma solidity ^0.4.24;

interface SolarTokenProxy {
    function initSolarTokenImpl(address _solarTokenImplAddr);
}

interface SolarTokenProxyFactoryInterface {
    function newProxy(
        address _creator,
        string _name,
        string _symbol,
        uint256 _decimals,
        address _votingFactoryAddr
    ) public view returns (address);
}

interface SolarTokenImplFactoryInterface {
    function newImpl(
        address _tokenProxyAddr,
        string _version,
        uint256 _chainId,
        address _creator
    ) public returns (address);
}

interface VotingFactoryInterface {

}

contract SolarTokenFactory {
    string[] solarTokenSymbolList;
    mapping(string => bool) haveSolarTokenSymbol;
    mapping(string => address) solarTokenProxyMap;
    mapping(string => address) solarTokenImplMap;

    SolarTokenProxyFactoryInterface tokenProxyFactory;
    SolarTokenImplFactoryInterface tokenImplFactory;
    VotingFactoryInterface votingFactory;

    constructor(address _tokenProxyFactoryAddr, address _tokenImplFactoryAddr, address _votingFactoryAddr) {
        tokenProxyFactory = SolarTokenProxyFactoryInterface(_tokenProxyFactoryAddr);
        tokenImplFactory = SolarTokenImplFactoryInterface(_tokenImplFactoryAddr);
        votingFactory = VotingFactoryInterface(_votingFactoryAddr);
    }

    function createToken(
        string _name,
        string _symbol,
        uint256 _decimals,
        string _version,
        uint256 _chainId
    ) public {
        require(!haveSolarTokenSymbol[_symbol], "symbol has been registered");

        address tokenProxyAddr = tokenProxyFactory.newProxy(address(this), _name, _symbol, _decimals, address(votingFactory));
        address tokenImplAddr = tokenImplFactory.newImpl(tokenProxyAddr, _version, _chainId, msg.sender);

        SolarTokenProxy(tokenProxyAddr).initSolarTokenImpl(tokenImplAddr);

        solarTokenSymbolList.push(_symbol);
        haveSolarTokenSymbol[_symbol] = true;
        solarTokenProxyMap[_symbol] = tokenProxyAddr;
        solarTokenImplMap[_symbol] = tokenImplAddr;

        emit CreateToken(_name, _symbol, _decimals, _version, _chainId, msg.sender, tokenProxyAddr, tokenImplAddr);
    }

    function getSolarTokenCount() public view returns (uint) {
        return solarTokenSymbolList.length;
    }

    function getSolarTokenSymbol(uint i) public view returns (string) {
        return solarTokenSymbolList[i];
    }

    function getSolarTokenProxyAddr(string _symbol) public view returns (address) {
        return solarTokenProxyMap[_symbol];
    }

    function getSolarTokenImplAddr(string _symbol) public view returns (address) {
        return solarTokenImplMap[_symbol];
    }

    event CreateToken(
        string _name,
        string _symbol,
        uint256 _decimals,
        string _version,
        uint256 _chainId,
        address _creator,
        address _tokenProxyAddr,
        address _tokenImplAdrr
    );
}
