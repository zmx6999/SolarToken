pragma solidity ^0.4.24;

import "./Voting.sol";

contract VotingFactory {
    function newRegularVoting(
        address _solarTokenAddr,
        string _title,
        string _description,
        uint _duration,
        bytes32[] _optionList
    ) public returns (address) {
        address voting = new RegularVoting(_solarTokenAddr, _title, _description, msg.sender, _duration, _optionList);
        emit NewRegularVoting(voting, _solarTokenAddr, _title, _description, msg.sender, _duration, _optionList);
        return voting;
    }

    function newSetAddressVoting(
        address _solarTokenAddr,
        string _title,
        string _description,
        address _creator,
        string _setFunc,
        address _newAddress
    ) public returns (address) {
        return new SetAddressVoting(_solarTokenAddr, _title, _description, _creator, _setFunc, _newAddress);
    }

    function newSetUintVoting(
        address _solarTokenAddr,
        string _title,
        string _description,
        address _creator,
        string _setFunc,
        uint _newUint
    ) public returns (address) {
        return new SetUintVoting(_solarTokenAddr, _title, _description, _creator, _setFunc, _newUint);
    }

    event NewRegularVoting(
        address _votingAddr,
        address _solarTokenAddr,
        string _title,
        string _description,
        address _creator,
        uint _duration,
        bytes32[] _optionList
    );
}
