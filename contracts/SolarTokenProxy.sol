pragma solidity ^0.4.24;

interface SolarTokenImplInterface {
    function transfer(address _from, address _to, uint256 _value) public returns (bool);
    function transferFrom(address _spender, address _from, address _to, uint256 _value) public returns (bool);
    function approve(address _owner, address _spender, uint256 _value) public returns (bool);
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
    SolarTokenImplInterface public solarTokenImpl;
    VotingFactoryInterface votingFactory;

    address public creator;
    bool solarTokenImplInitialized;

    mapping(address => bool) public votingList;

    constructor(address _creator, address _votingFactoryAddr) {
        creator = _creator;
        solarTokenImpl = SolarTokenImplInterface(address(0));
        votingFactory = VotingFactoryInterface(_votingFactoryAddr);

        implCreatorIncome = 0;
        implCreatorIncomePeriod = 1;
    }

    modifier onlyCreator {
        require(msg.sender == creator);
        _;
    }

    modifier notInitialized {
        require(!solarTokenImplInitialized, "address has been initialized");
        _;
    }

    modifier onlyImpl {
        require(msg.sender == address(solarTokenImpl), "permission denied");
        _;
    }

    modifier canConfirm {
        require(votingList[msg.sender]);
        _;
    }

    function initSolarTokenImpl(address _solarTokenImplAddr) public onlyCreator notInitialized {
        solarTokenImpl = SolarTokenImplInterface(_solarTokenImplAddr);
        solarTokenImplInitialized = true;
    }

    function makeSolarTokenImplUpgradeRequest(string _title, string _description, address _newSolarTokenImplAddr) public {
        address voting = votingFactory.newSetAddressVoting(address(this), _title, _description, msg.sender, "confirmSolarTokenImplUpgradeRequest(address)", _newSolarTokenImplAddr);
        votingList[voting] = true;
        emit MakeSolarTokenImplUpgradeRequest(voting, _title, _description, msg.sender, _newSolarTokenImplAddr);
    }

    function confirmSolarTokenImplUpgradeRequest(address newSolarTokenImplAddr) public canConfirm {
        solarTokenImpl = SolarTokenImplInterface(newSolarTokenImplAddr);
        votingList[msg.sender] = false;
        emit ConfirmSolarTokenImplUpgradeRequest(newSolarTokenImplAddr);
    }

    uint public implCreatorIncome;
    uint public implCreatorIncomePeriod;

    function makeImplCreatorIncomeUpgradeRequest(string _title, string _description, uint256 _newImplCreatorIncome) public {
        address voting = votingFactory.newSetUintVoting(address(this), _title, _description, msg.sender, "confirmImplCreatorIncomeUpgradeRequest(uint256)", _newImplCreatorIncome);
        votingList[voting] = true;
        emit MakeImplCreatorIncomeUpgradeRequest(voting, _title, _description, msg.sender, _newImplCreatorIncome);
    }

    function confirmImplCreatorIncomeUpgradeRequest(uint256 newImplCreatorIncome) public canConfirm {
        implCreatorIncome = newImplCreatorIncome;
        votingList[msg.sender] = false;
        emit ConfirmImplCreatorIncomeUpgradeRequest(newImplCreatorIncome);
    }

    function makeImplCreatorIncomePeriodUpgradeRequest(string _title, string _description, uint256 _newImplCreatorIncomePeriod) public {
        address voting = votingFactory.newSetUintVoting(address(this), _title, _description, msg.sender, "confirmImplCreatorIncomePeriodUpgradeRequest(uint256)", _newImplCreatorIncomePeriod);
        votingList[voting] = true;
        emit MakeImplCreatorIncomePeriodUpgradeRequest(voting, _title, _description, msg.sender, _newImplCreatorIncomePeriod);
    }

    function confirmImplCreatorIncomePeriodUpgradeRequest(uint256 newImplCreatorIncomePeriod) public canConfirm {
        implCreatorIncomePeriod = newImplCreatorIncomePeriod;
        votingList[msg.sender] = false;
        emit ConfirmImplCreatorIncomePeriodUpgradeRequest(newImplCreatorIncomePeriod);
    }

    event MakeSolarTokenImplUpgradeRequest(address _votingAddr, string _title, string _description, address _creator, address _newSolarTokenImplAddr);
    event ConfirmSolarTokenImplUpgradeRequest(address _newSolarTokenImplAddr);

    event MakeImplCreatorIncomeUpgradeRequest(address _votingAddr, string _title, string _description, address _creator, uint _newImplCreatorIncome);
    event ConfirmImplCreatorIncomeUpgradeRequest(uint _newImplCreatorIncome);

    event MakeImplCreatorIncomePeriodUpgradeRequest(address _votingAddr, string _title, string _description, address _creator, uint _newImplCreatorIncomePeriod);
    event ConfirmImplCreatorIncomePeriodUpgradeRequest(uint _newImplCreatorIncomePeriod);
}

contract SolarTokenStore is SolarTokenUpgrade {
    uint256 private _totalSupply;
    mapping(address => uint256) private _balanceOf;
    mapping(address => mapping(address => uint256)) private _allowance;
    mapping(address => uint256) private _freezeOf;

    constructor(address _creator, address _votingFactoryAddr) SolarTokenUpgrade(_creator, _votingFactoryAddr) {

    }

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
    string public name;
    string public symbol;
    uint256 public decimals;

    constructor(
        address _creator,
        string _name,
        string _symbol,
        uint256 _decimals,
        address _votingFactoryAddr
    ) SolarTokenStore(_creator, _votingFactoryAddr) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        return solarTokenImpl.transfer(msg.sender, _to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        return solarTokenImpl.transferFrom(msg.sender, _from, _to, _value);
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        return solarTokenImpl.approve(msg.sender, _spender, _value);
    }

    event Transfer(address indexed _from, address indexed _to, uint256 _value);

    function emitTransfer(address _from, address _to, uint256 _value) public onlyImpl {
        emit Transfer(_from, _to, _value);
    }

    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    function emitApproval(address _owner, address _spender, uint256 _value) public onlyImpl {
        emit Approval(_owner, _spender, _value);
    }
}
