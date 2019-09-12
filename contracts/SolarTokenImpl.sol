pragma solidity ^0.4.24;

import "./SafeMath.sol";

interface SolarTokenProxyInterface {
    function name() public view returns (string);

    function totalSupply() public view returns (uint256);
    function setTotalSupply(uint256 _value) public;

    function balanceOf(address _owner) public view returns (uint256);
    function setBalanceOf(address _owner, uint256 _value) public;

    function allowance(address _owner, address _spender) public view returns (uint256);
    function setAllowance(address _owner, address _spender, uint256 _value) public;

    function freezeOf(address _owner) public view returns (uint256);
    function setFreezeOf(address _owner, uint256 _value) public;

    function emitTransfer(address _from, address _to, uint256 _value) public;
    function emitApproval(address _owner, address _spender, uint256 _value) public;

    function implCreatorIncome() public view returns (uint);
    function implCreatorIncomePeriod() public view returns (uint);
}

contract SolarTokenImpl {
    string public version;
    uint256 public chainId;

    address public creator;
    uint public createTime;
    uint public lastWithdrawIncomeTime;

    SolarTokenProxyInterface tokenProxy;

    constructor(
        address _tokenProxyAddr,
        string _version,
        uint256 _chainId,
        address _creator
    ) {
        tokenProxy = SolarTokenProxyInterface(_tokenProxyAddr);
        version = _version;
        chainId = _chainId;

        creator = _creator;
        createTime = block.timestamp;
        lastWithdrawIncomeTime = createTime;

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                EIP712DOMAIN_TYPE_HASH,
                keccak256(bytes(tokenProxy.name())),
                keccak256(bytes(version)),
                chainId,
                address(this)
            )
        );
    }

    modifier onlyProxy {
        require(msg.sender == address(tokenProxy) || msg.sender == address(this), "permission denied");
        _;
    }

    modifier onlyCreator {
        require(msg.sender == creator);
        _;
    }

    function mintToken(address _owner, uint256 _value) public returns (bool) {
        require(_owner != address(0));

        tokenProxy.setBalanceOf(_owner,
            SafeMath.add(tokenProxy.balanceOf(_owner), _value)
        );
        tokenProxy.setTotalSupply(
            SafeMath.add(tokenProxy.totalSupply(), _value)
        );

        emit MintToken(_owner, _value);
        return true;
    }

    function _transfer(address _from, address _to, uint256 _value) internal {
        require(_to != address(0), "_to:invalid address");
        require(_from != _to, "_to:shouldn't be sender");

        require(_value > 0, "_value > 0");
        uint256 fromBalance = tokenProxy.balanceOf(_from);
        require(fromBalance >= _value, "insufficient balance");

        tokenProxy.setBalanceOf(_from,
            SafeMath.sub(fromBalance, _value)
        );
        tokenProxy.setBalanceOf(_to,
            SafeMath.add(tokenProxy.balanceOf(_to), _value)
        );

        tokenProxy.emitTransfer(_from, _to, _value);
    }

    function transfer(address _from, address _to, uint256 _value) public onlyProxy returns (bool) {
        _transfer(_from, _to, _value);
        return true;
    }

    function transferFrom(address _spender, address _from, address _to, uint256 _value) public onlyProxy returns (bool) {
        if (_spender != _from) {
            uint256 allowance = tokenProxy.allowance(_from, _spender);
            require(allowance >= _value, "_value has exceeded allowance");
            tokenProxy.setAllowance(_from, _spender,
                SafeMath.sub(allowance, _value)
            );
        }

        _transfer(_from, _to, _value);
        return true;
    }

    function approve(address _owner, address _spender, uint256 _value) public onlyProxy returns (bool) {
        if (_owner == _spender) return true;

        require(_spender != address(0), "_spender:invalid address");
        require(_value > 0, "_value > 0");

        tokenProxy.setAllowance(_owner, _spender, _value);
        tokenProxy.emitApproval(_owner, _spender, _value);

        return true;
    }

    function burn(uint256 _value) public returns (bool) {
        require(_value > 0, "_value > 0");
        uint256 balance = tokenProxy.balanceOf(msg.sender);
        require(balance >= _value, "insufficient balance");

        tokenProxy.setTotalSupply(
            SafeMath.sub(tokenProxy.totalSupply(), _value)
        );
        tokenProxy.setBalanceOf(msg.sender,
            SafeMath.sub(balance, _value)
        );

        emit Burn(msg.sender, _value);
        return true;
    }

    function freeze(uint256 _value) public returns (bool) {
        require(_value > 0, "_value > 0");
        uint256 balance = tokenProxy.balanceOf(msg.sender);
        require(balance >= _value, "insufficient balance");

        tokenProxy.setBalanceOf(msg.sender,
            SafeMath.sub(balance, _value)
        );
        tokenProxy.setFreezeOf(msg.sender,
            SafeMath.add(tokenProxy.freezeOf(msg.sender), _value)
        );

        emit Freeze(msg.sender, _value);
        return true;
    }

    function unfreeze(uint256 _value) public returns (bool) {
        require(_value > 0, "_value > 0");
        uint256 freezeAmount = tokenProxy.freezeOf(msg.sender);
        require(freezeAmount >= _value, "_value has exceeded freeze amount");

        tokenProxy.setFreezeOf(msg.sender,
            SafeMath.sub(freezeAmount, _value)
        );
        tokenProxy.setBalanceOf(msg.sender,
            SafeMath.add(tokenProxy.balanceOf(msg.sender), _value)
        );

        emit Unfreeze(msg.sender, _value);
        return true;
    }

    function batchTransfer(address[] _tos, uint256[] _values) public returns (bool) {
        require(_tos.length == _values.length, "_tos length should equal _values");

        for (uint i = 0; i < _tos.length; i++) {
            if (_tos[i] != address(0) && _tos[i] != msg.sender && _values[i] > 0) {
                _transfer(msg.sender, _tos[i], _values[i]);
            }
        }

        return true;
    }

    event MintToken(address indexed _owner, uint256 _value);
    event Burn(address indexed _owner, uint256 _value);
    event Freeze(address indexed _owner, uint256 _value);
    event Unfreeze(address indexed _owner, uint256 _value);

    bytes32 constant EIP712DOMAIN_TYPE_HASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    bytes32 DOMAIN_SEPARATOR;

    bytes32 constant TRANSFER_TYPE_HASH = keccak256(
        "transfer(address _from,address _to,uint256 _value)"
    );

    function transfer(address _from, address _to, uint256 _value, uint8 _v, bytes32 _r, bytes32 _s) public returns (bool) {
        bytes32 transferHash = keccak256(
            abi.encode(
                TRANSFER_TYPE_HASH,
                _from,
                _to,
                _value
            )
        );
        bytes32 message = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                transferHash
            )
        );
        require(ecrecover(message, _v, _r, _s) == _from);

        return this.transfer(_from, _to, _value);
    }

    bytes32 constant TRANSFER_FROM_TYPE_HASH = keccak256(
        "transferFrom(address _spender,address _from,address _to,uint256 _value)"
    );

    function transferFrom(address _spender, address _from, address _to, uint256 _value, uint8 _v, bytes32 _r, bytes32 _s) public returns (bool) {
        bytes32 transferFromHash = keccak256(
            abi.encode(
                TRANSFER_FROM_TYPE_HASH,
                _spender,
                _from,
                _to,
                _value
            )
        );
        bytes32 message = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                transferFromHash
            )
        );
        require(ecrecover(message, _v, _r, _s) == _spender);

        return this.transferFrom(_spender, _from, _to, _value);
    }

    bytes32 constant APPROVE_TYPE_HASH = keccak256(
        "approve(address _owner,address _spender,uint256 _value)"
    );

    function approve(address _owner, address _spender, uint256 _value, uint8 _v, bytes32 _r, bytes32 _s) public returns (bool) {
        bytes32 approveHash = keccak256(
            abi.encode(
                APPROVE_TYPE_HASH,
                _owner,
                _spender,
                _value
            )
        );
        bytes32 message = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                approveHash
            )
        );
        require(ecrecover(message, _v, _r, _s) == _owner);

        return this.approve(_owner, _spender, _value);
    }

    bytes32 constant BURN_TYPE_HASH = keccak256(
        "burn(uint256 _value)"
    );

    function burn(uint256 _value, uint8 _v, bytes32 _r, bytes32 _s) public returns (bool) {
        bytes32 burnHash = keccak256(
            abi.encode(
                BURN_TYPE_HASH,
                _value
            )
        );
        bytes32 message = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                burnHash
            )
        );
        require(ecrecover(message, _v, _r, _s) == msg.sender);

        return burn(_value);
    }

    bytes32 constant FREEZE_TYPE_HASH = keccak256(
        "freeze(uint256 _value)"
    );

    function freeze(uint256 _value, uint8 _v, bytes32 _r, bytes32 _s) public returns (bool) {
        bytes32 freezeHash = keccak256(
            abi.encode(
                FREEZE_TYPE_HASH,
                _value
            )
        );
        bytes32 message = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                freezeHash
            )
        );
        require(ecrecover(message, _v, _r, _s) == msg.sender);

        return freeze(_value);
    }

    bytes32 constant UNFREEZE_TYPE_HASH = keccak256(
        "unfreeze(uint256 _value)"
    );

    function unfreeze(uint256 _value, uint8 _v, bytes32 _r, bytes32 _s) public returns (bool) {
        bytes32 unfreezeHash = keccak256(
            abi.encode(
                UNFREEZE_TYPE_HASH,
                _value
            )
        );
        bytes32 message = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                unfreezeHash
            )
        );
        require(ecrecover(message, _v, _r, _s) == msg.sender);

        return unfreeze(_value);
    }

    function withdrawIncome() public onlyCreator returns (bool) {
        uint withdrawTime = block.timestamp;
        uint withdrawAmount = SafeMath.div(
            SafeMath.mul(
                tokenProxy.implCreatorIncome(),
                SafeMath.sub(withdrawTime, lastWithdrawIncomeTime)
            ),
            tokenProxy.implCreatorIncomePeriod()
        );
        lastWithdrawIncomeTime = withdrawTime;

        return mintToken(creator, withdrawAmount);
    }
}
