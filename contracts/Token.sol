pragma solidity ^0.4.8;

import "./SafeMath.sol";
import "./Receiver.sol";

contract ERC223 {
    function totalSupply() public view returns (uint256);

    function balanceOf(address who) public view returns (uint256);

    function transfer(address to, uint256 value) public returns (bool);

    function transferFrom(address from, address to, uint256 value) public returns (bool);

    function transfer(address to, uint value, bytes data) returns (bool ok);

    function transferFrom(address from, address to, uint value, bytes data) returns (bool ok);

    function allowance(address owner, address spender) public view returns (uint256);

    function approve(address spender, uint256 value) public returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract Token is ERC223 {

    using SafeMath for uint256;

    string public name = "Token";
    string public symbol = "TKN";
    uint8 public decimals = 8;

    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) internal allowed;

    uint256 totalSupply_;

    function Token(uint _totalSupply, uint _initialBalance, address _crowdFundingAddress) {
        totalSupply_ = _totalSupply;
        balances[_crowdFundingAddress] = _initialBalance;
    }

    function totalSupply() public view returns (uint256) {
        return totalSupply_;
    }

    function balanceOf(address _owner) public view returns (uint256) {
        return balances[_owner];
    }

    function transfer(address _to, uint _value, bytes _data) returns (bool success) {
        if (!_transfer(_to, _value)) throw;
        if (isContract(_to)) return contractFallback(msg.sender, _to, _value, _data);
        return true;
    }

    function transferFrom(address _from, address _to, uint _value, bytes _data) returns (bool success) {
        if (!_transferFrom(_from, _to, _value)) throw;
        if (isContract(_to)) return contractFallback(_from, _to, _value, _data);
        return true;
    }

    function transfer(address _to, uint _value) returns (bool success) {
        return transfer(_to, _value, new bytes(0));
    }

    function transferFrom(address _from, address _to, uint _value) returns (bool success) {
        return transferFrom(_from, _to, _value, new bytes(0));
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowed[_owner][_spender];
    }

    function increaseApproval(address _spender, uint _addedValue) public returns (bool) {
        allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }

    function decreaseApproval(address _spender, uint _subtractedValue) public returns (bool) {
        uint oldValue = allowed[msg.sender][_spender];
        if (_subtractedValue > oldValue) {
            allowed[msg.sender][_spender] = 0;
        } else {
            allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
        }
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }

    function _transfer(address _to, uint256 _value) internal returns (bool) {
        require(_to != address(0));
        require(_value <= balances[msg.sender]);
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function _transferFrom(address _from, address _to, uint256 _value) internal returns (bool) {
        require(_to != address(0));
        require(_value <= balances[_from]);
        require(_value <= allowed[_from][msg.sender]);
        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        emit Transfer(_from, _to, _value);
        return true;
    }

    function contractFallback(address _origin, address _to, uint _value, bytes _data) private returns (bool success) {
        ERC223Receiver receiver = ERC223Receiver(_to);
        return receiver.tokenFallback(msg.sender, _origin, _value, _data);
    }

    function isContract(address _addr) private returns (bool is_contract) {
        uint length;
        assembly {length := extcodesize(_addr)}
        return length > 0;
    }
}