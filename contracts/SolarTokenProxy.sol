pragma solidity ^0.4.24;

import "./SafeMath.sol";

interface SolarTokenImplInterface {
    function transfer(address _from, address _to, uint256 _value) public returns (bool);
    function transferFrom(address _spender, address _from, address _to, uint256 _value) public returns (bool);
    function approve(address _owner, address _spender, uint256 _value) public returns (bool);
    function mintToken(address _sender, address _owner, uint256 _value) public returns (bool);

    function creator() public view returns (address);
    function withdrawIncome() public returns (bool);
}

interface VotingFactoryInterface {
    function newSetAddressVoting(
        address _solarTokenAddr,
        string _title,
        string _description,
        address _creator,
        string _setFunc,
        address _newAddress
    ) public returns (address);

    function newSetUintVoting(
        address _solarTokenAddr,
        string _title,
        string _description,
        address _creator,
        string _setFunc,
        uint _newUint
    ) public returns (address);
}

contract SolarTokenUpgrade {
    VotingFactoryInterface votingFactory;

    address public creator;
    uint public createTime;

    mapping(address => bool) public votingList;

    constructor(address _votingFactoryAddr) {
        creator = msg.sender;
        createTime = block.timestamp;
        solarTokenImpl = SolarTokenImplInterface(address(0));
        votingFactory = VotingFactoryInterface(_votingFactoryAddr);

        implCreatorIncomePeriod = 3600;
    }

    modifier onlyCreator {
        require(msg.sender == creator);
        _;
    }

    modifier tokenImplInitialized {
        require(solarTokenImpl != address(0), "solarTokenImpl has not been initialized");
        _;
    }

    modifier tokenImplNotInitialized {
        require(solarTokenImpl == address(0), "solarTokenImpl has been initialized");
        _;
    }

    modifier onlyImpl {
        require(address(solarTokenImpl) != address(0) && msg.sender == address(solarTokenImpl), "permission denied");
        _;
    }

    modifier canConfirm {
        require(votingList[msg.sender]);
        _;
    }

    SolarTokenImplInterface public solarTokenImpl;
    mapping(address => bool) solarTokenImplHistory;

    function initSolarTokenImpl(address _solarTokenImplAddr) public onlyCreator tokenImplNotInitialized {
        require(_solarTokenImplAddr != address(0));
        solarTokenImpl = SolarTokenImplInterface(_solarTokenImplAddr);
        solarTokenImplHistory[_solarTokenImplAddr] = true;
    }

    function makeSolarTokenImplUpgradeRequest(string _title, string _description, address _newSolarTokenImplAddr) public returns (bool) {
        require(_newSolarTokenImplAddr != address(0));
        require(!solarTokenImplHistory[_newSolarTokenImplAddr]);
        require(msg.sender == SolarTokenImplInterface(_newSolarTokenImplAddr).creator());
        makeAddressUpgradeRequest("solarTokenImpl", "confirmSolarTokenImplUpgradeRequest(address)", _title, _description, _newSolarTokenImplAddr);
        return true;
    }

    function confirmSolarTokenImplUpgradeRequest(address _newSolarTokenImplAddr) public returns (bool) {
        solarTokenImpl.withdrawIncome();
        solarTokenImpl = SolarTokenImplInterface(_newSolarTokenImplAddr);
        confirmAddressUpgradeRequest("solarTokenImpl", _newSolarTokenImplAddr);
        solarTokenImplHistory[_newSolarTokenImplAddr] = true;
        return true;
    }

    uint public implCreatorIncome; // by kwh
    uint public implCreatorIncomePeriod;

    function makeImplCreatorIncomeUpgradeRequest(string _title, string _description, uint256 _newImplCreatorIncome) public returns (bool) {
        makeUintUpgradeRequest("implCreatorIncome", "confirmImplCreatorIncomeUpgradeRequest(uint256)", _title, _description, _newImplCreatorIncome);
        return true;
    }

    function confirmImplCreatorIncomeUpgradeRequest(uint256 _newImplCreatorIncome) public returns (bool) {
        implCreatorIncome = _newImplCreatorIncome;
        confirmUintUpgradeRequest("implCreatorIncome", _newImplCreatorIncome);
        return true;
    }

    function makeImplCreatorIncomePeriodUpgradeRequest(string _title, string _description, uint256 _newImplCreatorIncomePeriod) public returns (bool) {
        makeUintUpgradeRequest("implCreatorIncomePeriod", "confirmImplCreatorIncomePeriodUpgradeRequest(uint256)", _title, _description, _newImplCreatorIncomePeriod);
        return true;
    }

    function confirmImplCreatorIncomePeriodUpgradeRequest(uint256 _newImplCreatorIncomePeriod) public returns (bool) {
        implCreatorIncomePeriod = _newImplCreatorIncomePeriod;
        confirmUintUpgradeRequest("implCreatorIncomePeriod", _newImplCreatorIncomePeriod);
        return true;
    }

    uint public voterReward; // by kwh

    function makeVoterRewardUpgradeRequest(string _title, string _description, uint _newVoterReward) public returns (bool) {
        makeUintUpgradeRequest("voterReward", "confirmVoterRewardUpgradeRequest(uint256)", _title, _description, _newVoterReward);
        return true;
    }

    function confirmVoterRewardUpgradeRequest(uint _newVoterReward) public returns (bool) {
        voterReward = _newVoterReward;
        confirmUintUpgradeRequest("voterReward", _newVoterReward);
        return true;
    }

    function makeAddressUpgradeRequest(string _paramName, string _setFunc, string _title, string _description, address _newAddress) internal {
        address voting = votingFactory.newSetAddressVoting(address(this), _title, _description, msg.sender, _setFunc, _newAddress);
        votingList[voting] = true;
        emit MakeAddressUpgradeRequest(_paramName, voting, _title, _description, msg.sender, _newAddress);
    }

    function confirmAddressUpgradeRequest(string _paramName, address _newAddress) internal canConfirm {
        votingList[msg.sender] = false;
        emit ConfirmAddressUpgradeRequest(_paramName, _newAddress);
    }

    function makeUintUpgradeRequest(string _paramName, string _setFunc, string _title, string _description, uint _newUint) internal {
        address voting = votingFactory.newSetUintVoting(address(this), _title, _description, msg.sender, _setFunc, _newUint);
        votingList[voting] = true;
        emit MakeUintUpgradeRequest(_paramName, voting, _title, _description, msg.sender, _newUint);
    }

    function confirmUintUpgradeRequest(string _paramName, uint _newUint) internal canConfirm {
        votingList[msg.sender] = false;
        emit ConfirmUintUpgradeRequest(_paramName, _newUint);
    }

    event MakeAddressUpgradeRequest(string _paramName, address _votingAddr, string _title, string _description, address _creator, address _newAddress);
    event ConfirmAddressUpgradeRequest(string _paramName, address _newAddress);

    event MakeUintUpgradeRequest(string _paramName, address _votingAddr, string _title, string _description, address _creator, uint _newUint);
    event ConfirmUintUpgradeRequest(string _paramName, uint _newUint);
}

contract SolarToken is SolarTokenUpgrade {
    string public name;
    string public symbol;
    uint256 public decimals;

    uint public constant mintCycle = 31536000; // 365 days
    uint public kwhPerToken;
    uint public maxKwhPerToken;

    constructor(
        string _name,
        string _symbol,
        uint256 _decimals,
        address _votingFactoryAddr
    ) SolarTokenUpgrade(_votingFactoryAddr) {
        require(_decimals <= 18);

        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        refreshKwhPerToken();
    }

    function refreshKwhPerToken() public returns (bool) {
        maxKwhPerToken = 10 ** decimals;
        if (kwhPerToken >= maxKwhPerToken) {
            kwhPerToken = maxKwhPerToken;
            return true;
        }

        uint pastTime = SafeMath.sub(block.timestamp, createTime);
        uint cycleNum = SafeMath.div(pastTime, mintCycle);
        if (cycleNum > 255) cycleNum = 255;
        kwhPerToken = 2 ** cycleNum;
        if (kwhPerToken > maxKwhPerToken) kwhPerToken = maxKwhPerToken;
        return true;
    }
}

contract SolarTokenStore is SolarToken {
    uint256 private _totalSupply;
    mapping(address => uint256) private _balanceOf;
    mapping(address => mapping(address => uint256)) private _allowance;
    mapping(address => uint256) private _freezeOf;

    constructor(
        string _name,
        string _symbol,
        uint256 _decimals,
        address _votingFactoryAddr
    ) SolarToken(_name, _symbol, _decimals, _votingFactoryAddr) {}

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function setTotalSupply(uint256 _value) public onlyImpl {
        _totalSupply = _value;
    }

    function balanceOf(address _owner) public view returns (uint256) {
        return _balanceOf[_owner];
    }

    function setBalanceOf(address _owner, uint256 _value) public onlyImpl {
        _balanceOf[_owner] = _value;
    }

    function allowance(address _owner, address _spender) public view returns (uint256) {
        return _allowance[_owner][_spender];
    }

    function setAllowance(address _owner, address _spender, uint256 _value) public onlyImpl {
        _allowance[_owner][_spender] = _value;
    }

    function freezeOf(address _owner) public view returns (uint256) {
        return _freezeOf[_owner];
    }

    function setFreezeOf(address _owner, uint256 _value) public onlyImpl {
        _freezeOf[_owner] = _value;
    }
}

contract SolarTokenProxy is SolarTokenStore {
    constructor(
        string _name,
        string _symbol,
        uint256 _decimals,
        address _votingFactoryAddr
    ) SolarTokenStore(_name, _symbol, _decimals, _votingFactoryAddr) {}

    function transfer(address _to, uint256 _value) public tokenImplInitialized returns (bool) {
        return solarTokenImpl.transfer(msg.sender, _to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) public tokenImplInitialized returns (bool) {
        return solarTokenImpl.transferFrom(msg.sender, _from, _to, _value);
    }

    function approve(address _spender, uint256 _value) public tokenImplInitialized returns (bool) {
        return solarTokenImpl.approve(msg.sender, _spender, _value);
    }

    function mintToken(address _owner, uint256 _value) public tokenImplInitialized returns (bool) {
        return solarTokenImpl.mintToken(msg.sender, _owner, _value);
    }

    event Transfer(address indexed _from, address indexed _to, uint256 _value);

    function emitTransfer(address _from, address _to, uint256 _value) public onlyImpl {
        emit Transfer(_from, _to, _value);
    }

    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    function emitApproval(address _owner, address _spender, uint256 _value) public onlyImpl {
        emit Approval(_owner, _spender, _value);
    }

    event MintToken(address indexed _sender, address indexed _owner, uint256 _kwh, uint256 _value);

    function emitMintToken(address _sender, address _owner, uint256 _kwh, uint256 _value) public onlyImpl {
        emit MintToken(_sender, _owner, _kwh, _value);
    }
}
