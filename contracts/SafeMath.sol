pragma solidity ^0.4.24;

library SafeMath {
    function add(uint x, uint y) internal pure returns (uint) {
        uint z = x + y;
        require(z >= x && z >= y);
        return z;
    }

    function sub(uint x, uint y) internal pure returns (uint) {
        require(x >= y);
        uint z = x - y;
        return z;
    }

    function mul(uint x, uint y) internal pure returns (uint) {
        uint z = x * y;
        require(y == 0 || x == z / y);
        return z;
    }

    function div(uint x, uint y) internal pure returns (uint) {
        require(y > 0);
        uint z=x / y;
        require(x == z * y + x % y);
        return z;
    }
}
