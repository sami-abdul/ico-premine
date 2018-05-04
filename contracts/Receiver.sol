pragma solidity ^0.4.8;

contract ERC223Receiver {
    function tokenFallback(address _sender, address _origin, uint _value, bytes _data) returns (bool ok);
}

contract Receiver is ERC223Receiver {

    Tkn tkn;

    struct Tkn {
        address addr;
        address sender;
        address origin;
        uint256 value;
        bytes data;
        bytes4 sig;
    }

    function () tokenPayable {
        LogTokenPayable(0, tkn.addr, tkn.sender, tkn.value);
    }

    function supportsToken(address token) returns (bool) {
        return true;
    }

    event LogTokenPayable(uint i, address token, address sender, uint value);

    function tokenFallback(address _sender, address _origin, uint _value, bytes _data) returns (bool ok) {
        if (!supportsToken(msg.sender)) return false;

        tkn = Tkn(msg.sender, _sender, _origin, _value, _data, getSig(_data));
        __isTokenFallback = true;
        if (!address(this).delegatecall(_data)) return false;

        __isTokenFallback = false;

        return true;
    }

    function getSig(bytes _data) private returns (bytes4 sig) {
        uint l = _data.length < 4 ? _data.length : 4;
        for (uint i = 0; i < l; i++) {
            sig = bytes4(uint(sig) + uint(_data[i]) * (2 ** (8 * (l - 1 - i))));
        }
    }

    bool __isTokenFallback;

    modifier tokenPayable {
        if (!__isTokenFallback) throw;
        _;
    }
}