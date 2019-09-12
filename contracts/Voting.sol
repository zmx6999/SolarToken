pragma solidity ^0.4.24;

import "./SafeMath.sol";

interface SolarTokenInterface {
    function totalSupply() public view returns (uint256);
    function balanceOf(address _owner) public view returns (uint256);

    function transfer(address _to, uint256 _value) public returns (bool);
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool);
}

contract Voting {
    SolarTokenInterface solarToken;
    string public title;
    string public description;
    address public creator;
    uint public createTime;
    uint public result;

    mapping(uint => uint) public voteCount;
    mapping(address => uint) public voteOption;
    mapping(address => uint) public deposit;

    address[] voterList;
    mapping(address => bool) voterRegistered;

    constructor(
        address _solarTokenAddr,
        string _title,
        string _description,
        address _creator
    ) {
        solarToken = SolarTokenInterface(_solarTokenAddr);
        title = _title;
        description = _description;

        creator = _creator;
        createTime = block.timestamp;
    }

    function _lock(uint _value) internal notFinish canVote {
        registerVoter();

        solarToken.transferFrom(msg.sender, address(this), _value);
        deposit[msg.sender] = SafeMath.add(deposit[msg.sender], _value);
        addWeight(_value);
    }

    function free(uint _value) public notFinish canVote returns (bool) {
        subWeight(_value);
        deposit[msg.sender] = SafeMath.sub(deposit[msg.sender], _value);
        solarToken.transfer(msg.sender, _value);
        return true;
    }

    function registerVoter() internal {
        if (!voterRegistered[msg.sender]) {
            voterList.push(msg.sender);
            voterRegistered[msg.sender] = true;
        }
    }

    function addWeight(uint _value) internal {
        uint optionId = voteOption[msg.sender];
        if (optionId > 0) {
            voteCount[optionId] = SafeMath.add(voteCount[optionId], _value);
        }
    }

    function subWeight(uint _value) internal {
        uint optionId = voteOption[msg.sender];
        if (optionId > 0) {
            voteCount[optionId] = SafeMath.sub(voteCount[optionId], _value);
        }
    }

    function _vote(uint _optionId) internal notFinish canVote {
        uint value = deposit[msg.sender];
        subWeight(value);
        voteOption[msg.sender] = _optionId;
        addWeight(value);
    }

    function _finish(uint _result) internal notFinish {
        result = _result;
        refund();
    }

    function refund() internal {
        uint i = 0;
        for ( ; i < voterList.length; ) {
            address voter = voterList[i];
            solarToken.transfer(voter, deposit[voter]);
            i = SafeMath.add(i, 1);
        }
    }

    modifier notFinish {
        require(result == 0);
        _;
    }

    modifier canVote {
        require(msg.sender != creator);
        _;
    }
}

contract RegularVoting is Voting {
    uint public duration;

    mapping(uint => bytes32) public optionList;
    uint public totalOption;

    constructor(
        address _solarTokenAddr,
        string _title,
        string _description,
        address _creator,
        uint _duration,
        bytes32[] _optionList
    ) Voting(_solarTokenAddr, _title, _description, _creator) {
        duration = _duration;

        uint i = 0;
        for ( ; i < _optionList.length; ) {
            if (_optionList[i] != 0x0) {
                totalOption = SafeMath.add(totalOption, 1);
                optionList[totalOption] = _optionList[i];
            }
            i = SafeMath.add(i, 1);
        }
        require(totalOption >= 2);
    }

    function lock(uint _value) public returns (bool) {
        require(block.timestamp <= SafeMath.add(createTime, duration));
        _lock(_value);
        return true;
    }

    function vote(uint _optionId) public returns (bool) {
        require(block.timestamp <= SafeMath.add(createTime, duration));
        require(_optionId <= totalOption);
        _vote(_optionId);
        return true;
    }

    function finish() public returns (bool) {
        require(block.timestamp > SafeMath.add(createTime, duration));
        uint _result;
        uint maxVote = 0;
        uint i = 1;
        for ( ; i <= totalOption; ) {
            if (maxVote < voteCount[i]) {
                _result = i;
                maxVote = voteCount[i];
            }
            i = SafeMath.add(i, 1);
        }

        _finish(_result);

        return true;
    }
}

contract ExecutiveVoting is Voting {
    uint public constant quorum = 60;

    constructor(
        address _solarTokenAddr,
        string _title,
        string _description,
        address _creator
    ) Voting(_solarTokenAddr, _title, _description, _creator) {

    }

    function lock_(uint _value) internal {
        _lock(_value);
        if (percent(1) >= quorum) _finish(1);
    }

    function vote_(uint _optionId) internal {
        require(_optionId <= 1);
        _vote(_optionId);
        if (percent(1) >= quorum) _finish(1);
    }

    function percent(uint _optionId) internal view returns (uint) {
        return SafeMath.div(
            SafeMath.mul(voteCount[_optionId], 100),
            SafeMath.sub(solarToken.totalSupply(), solarToken.balanceOf(creator))
        );
    }
}

contract SetAddressVoting is ExecutiveVoting {
    bytes4 setFunc;
    address newAddress;

    constructor(
        address _solarTokenAddr,
        string _title,
        string _description,
        address _creator,
        string _setFunc,
        address _newAddress
    ) ExecutiveVoting(_solarTokenAddr, _title, _description, _creator) {
        setFunc = bytes4(keccak256(_setFunc));
        newAddress = _newAddress;
    }

    function lock(uint _value) public returns (bool) {
        lock_(_value);
        if (percent(1) >= quorum) require(solarToken.call(setFunc, newAddress));
        return true;
    }

    function vote(uint _optionId) public returns (bool) {
        vote_(_optionId);
        if (percent(1) >= quorum) require(solarToken.call(setFunc, newAddress));
        return true;
    }
}
