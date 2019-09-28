pragma solidity ^0.4.24;

import "./SafeMath.sol";

interface SolarTokenInterface {
    function totalSupply() public view returns (uint256);
    function balanceOf(address _owner) public view returns (uint256);

    function transfer(address _to, uint256 _value) public returns (bool);
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool);

    function voterReward() public view returns (uint256);
    function mintToken(address _owner, uint256 _value) public returns (bool);
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
        refund(_result);
    }

    function refund(uint _result) internal {
        uint i = 0;
        for ( ; i < voterList.length; ) {
            address voter = voterList[i];
            solarToken.transfer(voter, deposit[voter]);
            rewardVoter(voter, _result);
            i = SafeMath.add(i, 1);
        }
    }

    function rewardVoter(address voter, uint _result) internal {
        if (voteOption[voter] == _result) {
            uint voterReward = solarToken.voterReward();
            solarToken.mintToken(voter, voterReward);
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
    // uint public constant minDuration = 604800; // 1 week
    uint public constant minDuration = 1200;

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
        require(_duration >= minDuration);

        duration = _duration;

        uint i = 0;
        for ( ; i < _optionList.length; ) {
            if (_optionList[i] != 0x0) {
                totalOption = SafeMath.add(totalOption, 1);
                optionList[totalOption] = _optionList[i];
            }
            i = SafeMath.add(i, 1);
        }
        require(totalOption >= 2 && totalOption <= 10);
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
    string public setFunc;
    address public newAddress;

    constructor(
        address _solarTokenAddr,
        string _title,
        string _description,
        address _creator,
        string _setFunc,
        address _newAddress
    ) ExecutiveVoting(_solarTokenAddr, _title, _description, _creator) {
        setFunc = _setFunc;
        newAddress = _newAddress;
    }

    function lock(uint _value) public returns (bool) {
        lock_(_value);
        if (result == 1) require(solarToken.call(bytes4(keccak256(setFunc)), newAddress));
        return true;
    }

    function vote(uint _optionId) public returns (bool) {
        vote_(_optionId);
        if (result == 1) require(solarToken.call(bytes4(keccak256(setFunc)), newAddress));
        return true;
    }
}

contract SetUintVoting is ExecutiveVoting {
    string public setFunc;
    uint public newUint;

    constructor(
        address _solarTokenAddr,
        string _title,
        string _description,
        address _creator,
        string _setFunc,
        uint _newUint
    ) ExecutiveVoting(_solarTokenAddr, _title, _description, _creator) {
        setFunc = _setFunc;
        newUint = _newUint;
    }

    function lock(uint _value) public returns (bool) {
        lock_(_value);
        if (result == 1) require(solarToken.call(bytes4(keccak256(setFunc)), newUint));
        return true;
    }

    function vote(uint _optionId) public returns (bool) {
        vote_(_optionId);
        if (result == 1) require(solarToken.call(bytes4(keccak256(setFunc)), newUint));
        return true;
    }
}
