pragma solidity ^0.4.18;

// ----------------------------------------------------------------------------
// EROS token
//
// Symbol      : ELOVE
// Name        : ELOVE Token for eLOVE Social Network
// Total supply: 200,000,000
// Decimals    : 2

contract ERC20Interface {
    function totalSupply() public constant returns (uint);
    function balanceOf(address tokenOwner) public constant returns (uint balance);
    function allowance(address tokenOwner, address spender) public constant returns (uint remaining);
    function transfer(address to, uint tokens) public returns (bool success);
    function approve(address spender, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
    event Burn(address indexed burner, uint256 value);
}

// ----------------------------------------------------------------------------
// Contract function to receive approval and execute function in one call
// Borrowed from MiniMeToken
contract ApproveAndCallFallBack {
    function receiveApproval(address from, uint256 tokens, address token, bytes data) public;
}

// ----------------------------------------------------------------------------
// Owned contract
contract Owned {
    
    struct Investor {
        address sender;
        uint amount;
        bool kyced;
    }
    
    address public owner;
    address public newOwner;
    
    // List of investors with invested amount in ETH
    Investor[] public investors;
    
    mapping(address => uint) public mapInvestors;
    mapping(address => bool) public founders;
    
    event OwnershipTransferred(address indexed _from, address indexed _to);

    function Owned() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }
    
    // Give KYC status, so token can be traded by this wallet
    function changeKYCStatus(address inv, bool kycStatus) onlyOwner public returns (bool success) {
        require(kycStatus == !investors[mapInvestors[inv]-1].kyced);
        investors[mapInvestors[inv]-1].kyced = kycStatus;
        return true;
    }
    
    // Give KYC status in batch
    // investor separated by ';'
    function changeKYCStatusInBatch(string invs, bool kycStatus) onlyOwner public {
        //string[] storage listInvestors = invs.split(";");
    }
    
    function isExistInvestor(address inv) public constant returns (bool exist) {
        return mapInvestors[inv] != 0;
    }
    
    function isExistFounder(address _founder) public constant returns (bool exist) {
        return founders[_founder];
    }
    
    function removeFounder(address _founder) onlyOwner public returns (bool success) {
        require(founders[_founder]);
        founders[_founder] = false;
        return true;
    }
    
    function addFounder(address _founder) onlyOwner public returns (bool success) {
        require(!founders[_founder]);
        founders[_founder] = true;
        return true;
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        newOwner = _newOwner;
    }
    
    function acceptOwnership() public {
        require(msg.sender == newOwner);
        OwnershipTransferred(owner, newOwner);
        owner = newOwner;
        newOwner = address(0);
    }
}

// ----------------------------------------------------------------------------
// ERC20 Token, with the addition of symbol, name and decimals and an
// initial fixed supply
// ----------------------------------------------------------------------------
contract ELOVEToken is ERC20Interface, Owned {
    using SafeMath for uint;
    using Strings for string;

    string public symbol;
    string public name;
    uint8 public decimals;
    uint public _totalSupply;
    
    uint minInvest = 1 ether;
    uint maxInvest = 500 ether;
    
    uint softcap = 5000 ether;
    uint hardcap = 40000 ether;

    uint icoStartDate;
    
    uint[4] roundEnd;
    uint[4] roundTokenLeft;
    uint[4] roundDiscount;
    
    uint tokenLockTime;
    bool icoEnded = false;
    
    mapping(address => uint) balances;
    mapping(address => mapping(address => uint)) allowed;

    uint etherExRate = 2000;

    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------
    function ELOVEToken(string tName, string tSymbol) public {
        symbol = tSymbol;
        name = tName;
        decimals = 2;
        _totalSupply = 200000000 * 10**uint(decimals); // 200.000.000 tokens
        
        icoStartDate            = 1518566401;   // 2018/02/14 00:00:01 AM
        
        // Ending time for each round
        // pre-ICO round 1 : ends 28/02/2018, 10M tokens limit, 40% discount
        // pre-ICO round 2 : ends 15/03/2018, 10M tokens limit, 30% discount
        // crowdsale round 1 : ends 15/04/2018, 30M tokens limit, 10% discount
        // crowdsale round 2 : ends 30/04/2018, 30M tokens limit, 0% discount
        roundEnd = [1519862400, 1521158400, 1523836800, 1525132800];
        roundTokenLeft = [1000000000, 1000000000, 3000000000, 3000000000];
        roundDiscount = [40, 30, 10, 0];
        
        // Time to lock all ERC20 transfer 
        tokenLockTime = 1572566400;     // 2019/11/01 after 18 months
        
        balances[owner] = _totalSupply;
        Transfer(address(0), owner, _totalSupply);
    }
    
    // Token left for each round
    function roundLeft(uint round) public constant returns (uint) {
        return roundTokenLeft[round];
    }
    
    // 
    function setRoundEnd(uint round, uint newTime) onlyOwner public {
        require(now<newTime);
        if (round>0) {
            require(newTime>roundEnd[round-1]);
        } else {
            require(newTime<roundEnd[1]);
        }
        roundEnd[round] = newTime;
    }
    
    function setEthExRate(uint newExRate) onlyOwner public {
        etherExRate = newExRate;
    }
    
    function setLockTime(uint newLockTime) onlyOwner public {
        require(now<newLockTime);
        tokenLockTime = newLockTime;
    }

    // ------------------------------------------------------------------------
    // Total supply
    // ------------------------------------------------------------------------
    function totalSupply() public constant returns (uint) {
        return _totalSupply - balances[address(0)];
    }

    // ------------------------------------------------------------------------
    // Get the token balance for account `tokenOwner`
    // ------------------------------------------------------------------------
    function balanceOf(address tokenOwner) public constant returns (uint balance) {
        return balances[tokenOwner];
    }
    
    // ------------------------------------------------------------------------
    // Transfer the balance from token owner's account to `to` account
    // - Owner's account must have sufficient balance to transfer
    // - 0 value transfers are allowed
    // ------------------------------------------------------------------------
    function transfer(address to, uint tokens) public returns (bool success) {
        require(icoEnded);
        // transaction is in tradable period
        require(now<tokenLockTime);
        // sender is not founder, and must be kyc-ed
        require(!founders[msg.sender] && investors[mapInvestors[msg.sender]-1].kyced);
        // sender either is owner or recipient is not 0x0 address
        require(msg.sender == owner || to != 0x0);
        
        balances[msg.sender] = balances[msg.sender].sub(tokens);
        balances[to] = balances[to].add(tokens);
        Transfer(msg.sender, to, tokens);
        return true;
    }

    // ------------------------------------------------------------------------
    // Token owner can approve for `spender` to transferFrom(...) `tokens`
    // from the token owner's account
    //
    // https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20-token-standard.md
    // recommends that there are no checks for the approval double-spend attack
    // as this should be implemented in user interfaces 
    // ------------------------------------------------------------------------
    function approve(address spender, uint tokens) public returns (bool success) {
        allowed[msg.sender][spender] = tokens;
        Approval(msg.sender, spender, tokens);
        return true;
    }


    // ------------------------------------------------------------------------
    // Transfer `tokens` from the `from` account to the `to` account
    // 
    // The calling account must already have sufficient tokens approve(...)-d
    // for spending from the `from` account and
    // - From account must have sufficient balance to transfer
    // - Spender must have sufficient allowance to transfer
    // - 0 value transfers are allowed
    // ------------------------------------------------------------------------
    function transferFrom(address from, address to, uint tokens) public returns (bool success) {
        require(!founders[from] && investors[mapInvestors[from]-1].kyced);
        
        balances[from] = balances[from].sub(tokens);
        allowed[from][msg.sender] = allowed[from][msg.sender].sub(tokens);
        balances[to] = balances[to].add(tokens);
        Transfer(from, to, tokens);
        return true;
    }

    // ------------------------------------------------------------------------
    // Returns the amount of tokens approved by the owner that can be
    // transferred to the spender's account
    // ------------------------------------------------------------------------
    function allowance(address tokenOwner, address spender) public constant returns (uint remaining) {
        return allowed[tokenOwner][spender];
    }

    // ------------------------------------------------------------------------
    // Token owner can approve for `spender` to transferFrom(...) `tokens`
    // from the token owner's account. The `spender` contract function
    // `receiveApproval(...)` is then executed
    // ------------------------------------------------------------------------
    function approveAndCall(address spender, uint tokens, bytes data) public returns (bool success) {
        allowed[msg.sender][spender] = tokens;
        Approval(msg.sender, spender, tokens);
        ApproveAndCallFallBack(spender).receiveApproval(msg.sender, tokens, this, data);
        return true;
    }
    
    function processRound(uint round) internal {
        // Token left for each round must be greater than 0
        require(roundTokenLeft[round]>0);
        // calculate number of tokens can be bought, given number of ether from sender, with discount rate accordingly
        var tokenCanBeBought = (10**uint(decimals)*msg.value*etherExRate*100).div(10**18*(100-roundDiscount[round]));
        if (tokenCanBeBought<roundTokenLeft[round]) {
            balances[owner] = balances[owner] - tokenCanBeBought;
            balances[msg.sender] = balances[msg.sender] + tokenCanBeBought;
            roundTokenLeft[round] = roundTokenLeft[round]-tokenCanBeBought;
            
            if (mapInvestors[msg.sender] > 0) {
                // if investors already existed, add amount to the invested sum
                investors[mapInvestors[msg.sender]-1].amount += msg.value;
            } else {
                uint ind = investors.push(Investor(msg.sender, msg.value, false));                
                mapInvestors[msg.sender] = ind;
            }
        } else {
            var neededEtherToBuy = (10**18*roundTokenLeft[round]*(100-roundDiscount[round])).div(10**uint(decimals)*etherExRate*100);
            balances[owner] = balances[owner] - roundTokenLeft[round];
            balances[msg.sender] = balances[msg.sender] + roundTokenLeft[round];
            roundTokenLeft[round] = 0;
            
            if (mapInvestors[msg.sender] > 0) {
                // if investors already existed, add amount to the invested sum
                investors[mapInvestors[msg.sender]-1].amount += neededEtherToBuy;
            } else {
                uint index = investors.push(Investor(msg.sender, neededEtherToBuy, false));  
                mapInvestors[msg.sender] = index;
            }
            
            // send back ether to sender 
            msg.sender.transfer(msg.value-neededEtherToBuy);
        }
    }

    // ------------------------------------------------------------------------
    // Accept ETH for this crowdsale
    // ------------------------------------------------------------------------
    function () public payable {
        require(!icoEnded);
        uint currentTime = now;
        require (currentTime>icoStartDate);
        require (msg.value>= minInvest && msg.value<=maxInvest);
        
        if (currentTime<roundEnd[0]) {
            processRound(0);
        } else if (currentTime<roundEnd[1]) {
            processRound(1);
        } else if (currentTime<roundEnd[2]) {
            processRound(2);
        } else if (currentTime<roundEnd[3]) {
            processRound(3);
        } else {
            // crowdsale ends, check success conditions
            // run once
            if (this.balance<softcap) {
                // time to send back funds to investors
                for(uint i = 0; i<investors.length; i++) {
                    investors[i].sender.transfer(investors[i].amount);
                }
            } else {
                // burn un-sold tokens
                uint sumToBurn = roundTokenLeft[0] + roundTokenLeft[1] + roundTokenLeft[2] + roundTokenLeft[3];
                balances[owner] = balances[owner] - sumToBurn;
                _totalSupply = _totalSupply - sumToBurn;
                
                roundTokenLeft[0] = roundTokenLeft[1] = roundTokenLeft[2] = roundTokenLeft[3] = 0;
            }
            
            // give back ETH to sender
            msg.sender.transfer(msg.value);
            icoEnded = true;
        }
    }
    
    function withdrawEtherToOwner() onlyOwner public {   
        require(now>roundEnd[3] && this.balance>softcap);
        owner.transfer(this.balance);
    }

    // ------------------------------------------------------------------------
    // Owner can transfer out any accidentally sent ERC20 tokens
    // ------------------------------------------------------------------------
    function transferAnyERC20Token(address tokenAddress, uint tokens) public onlyOwner returns (bool success) {
        return ERC20Interface(tokenAddress).transfer(owner, tokens);
    }
}

// ----------------------------------------------------------------------------
// Safe maths
// ----------------------------------------------------------------------------
library SafeMath {
    function add(uint a, uint b) internal pure returns (uint c) {
        c = a + b;
        require(c >= a);
    }
    function sub(uint a, uint b) internal pure returns (uint c) {
        require(b <= a);
        c = a - b;
    }
    function mul(uint a, uint b) internal pure returns (uint c) {
        c = a * b;
        require(a == 0 || c / a == b);
    }
    function div(uint a, uint b) internal pure returns (uint c) {
        require(b > 0);
        c = a / b;
    }
}

library Strings {

    /**
     * Concat (High gas cost)
     * 
     * Appends two strings together and returns a new value
     * 
     * @param _base When being used for a data type this is the extended object
     *              otherwise this is the string which will be the concatenated
     *              prefix
     * @param _value The value to be the concatenated suffix
     * @return string The resulting string from combinging the base and value
     */
    function concat(string _base, string _value) pure internal returns (string) {
        bytes memory _baseBytes = bytes(_base);
        bytes memory _valueBytes = bytes(_value);

        assert(_valueBytes.length > 0);

        string memory _tmpValue = new string(_baseBytes.length + 
            _valueBytes.length);
        bytes memory _newValue = bytes(_tmpValue);

        uint i;
        uint j;

        for(i = 0; i < _baseBytes.length; i++) {
            _newValue[j++] = _baseBytes[i];
        }

        for(i = 0; i<_valueBytes.length; i++) {
            _newValue[j++] = _valueBytes[i];
        }

        return string(_newValue);
    }

    /**
     * Index Of
     *
     * Locates and returns the position of a character within a string
     * 
     * @param _base When being used for a data type this is the extended object
     *              otherwise this is the string acting as the haystack to be
     *              searched
     * @param _value The needle to search for, at present this is currently
     *               limited to one character
     * @return int The position of the needle starting from 0 and returning -1
     *             in the case of no matches found
     */
    function indexOf(string _base, string _value) pure internal returns (int) {
        return _indexOf(_base, _value, 0);
    }

    /**
     * Index Of
     *
     * Locates and returns the position of a character within a string starting
     * from a defined offset
     * 
     * @param _base When being used for a data type this is the extended object
     *              otherwise this is the string acting as the haystack to be
     *              searched
     * @param _value The needle to search for, at present this is currently
     *               limited to one character
     * @param _offset The starting point to start searching from which can start
     *                from 0, but must not exceed the length of the string
     * @return int The position of the needle starting from 0 and returning -1
     *             in the case of no matches found
     */
    function _indexOf(string _base, string _value, uint _offset) pure internal returns (int) {
        bytes memory _baseBytes = bytes(_base);
        bytes memory _valueBytes = bytes(_value);

        assert(_valueBytes.length == 1);

        for(uint i = _offset; i < _baseBytes.length; i++) {
            if (_baseBytes[i] == _valueBytes[0]) {
                return int(i);
            }
        }

        return -1;
    }

    /**
     * Length
     * 
     * Returns the length of the specified string
     * 
     * @param _base When being used for a data type this is the extended object
     *              otherwise this is the string to be measured
     * @return uint The length of the passed string
     */
    function length(string _base) pure internal returns (uint) {
        bytes memory _baseBytes = bytes(_base);
        return _baseBytes.length;
    }

    /**
     * Sub String
     * 
     * Extracts the beginning part of a string based on the desired length
     * 
     * @param _base When being used for a data type this is the extended object
     *              otherwise this is the string that will be used for 
     *              extracting the sub string from
     * @param _length The length of the sub string to be extracted from the base
     * @return string The extracted sub string
     */
    function substring(string _base, int _length) pure internal returns (string) {
        return _substring(_base, _length, 0);
    }

    /**
     * Sub String
     * 
     * Extracts the part of a string based on the desired length and offset. The
     * offset and length must not exceed the lenth of the base string.
     * 
     * @param _base When being used for a data type this is the extended object
     *              otherwise this is the string that will be used for 
     *              extracting the sub string from
     * @param _length The length of the sub string to be extracted from the base
     * @param _offset The starting point to extract the sub string from
     * @return string The extracted sub string
     */
    function _substring(string _base, int _length, int _offset) pure internal returns (string) {
        bytes memory _baseBytes = bytes(_base);

        assert(uint(_offset+_length) <= _baseBytes.length);

        string memory _tmp = new string(uint(_length));
        bytes memory _tmpBytes = bytes(_tmp);

        uint j = 0;
        for(uint i = uint(_offset); i < uint(_offset+_length); i++) {
          _tmpBytes[j++] = _baseBytes[i];
        }

        return string(_tmpBytes);
    }

    /**
     * String Split (Very high gas cost)
     *
     * Splits a string into an array of strings based off the delimiter value.
     * Please note this can be quite a gas expensive function due to the use of
     * storage so only use if really required.
     *
     * @param _base When being used for a data type this is the extended object
     *               otherwise this is the string value to be split.
     * @param _value The delimiter to split the string on which must be a single
     *               character
     * @return string[] An array of values split based off the delimiter, but
     *                  do not container the delimiter.
     */
    function split(string _base, string _value)
        internal
        returns (string[] storage splitArr) {
        bytes memory _baseBytes = bytes(_base);
        uint _offset = 0;

        while(_offset < _baseBytes.length-1) {

            int _limit = _indexOf(_base, _value, _offset);
            if (_limit == -1) {
                _limit = int(_baseBytes.length);
            }

            string memory _tmp = new string(uint(_limit)-_offset);
            bytes memory _tmpBytes = bytes(_tmp);

            uint j = 0;
            for(uint i = _offset; i < uint(_limit); i++) {
                _tmpBytes[j++] = _baseBytes[i];
            }
            _offset = uint(_limit) + 1;
            splitArr.push(string(_tmpBytes));
        }
        return splitArr;
    }

    /**
     * Compare To
     * 
     * Compares the characters of two strings, to ensure that they have an 
     * identical footprint
     * 
     * @param _base When being used for a data type this is the extended object
     *               otherwise this is the string base to compare against
     * @param _value The string the base is being compared to
     * @return bool Simply notates if the two string have an equivalent
     */
    function compareTo(string _base, string _value) pure internal returns (bool) {
        bytes memory _baseBytes = bytes(_base);
        bytes memory _valueBytes = bytes(_value);

        if (_baseBytes.length != _valueBytes.length) {
            return false;
        }

        for(uint i = 0; i < _baseBytes.length; i++) {
            if (_baseBytes[i] != _valueBytes[i]) {
                return false;
            }
        }

        return true;
    }

}

