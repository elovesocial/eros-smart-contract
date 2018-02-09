pragma solidity ^0.4.18;

// ----------------------------------------------------------------------------
// EROS token
//
// Symbol      : eROS
// Name        : eLOVE Token
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
//
// Borrowed from MiniMeToken
// ----------------------------------------------------------------------------
contract ApproveAndCallFallBack {
    function receiveApproval(address from, uint256 tokens, address token, bytes data) public;
}

// ----------------------------------------------------------------------------
// Owned contract
// ----------------------------------------------------------------------------
contract Owned {
    
    struct Investor {
        address sender;
        uint amount;
        bool kyced;
    }
    
    address public owner;
    address public newOwner;
    
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
    
    function giveKYC(address inv) onlyOwner public returns (bool success) {
        investors[mapInvestors[inv]-1].kyced = true;
        return true;
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
contract EROSToken is ERC20Interface, Owned {
    using SafeMath for uint;

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
    function EROSToken(string tName, string tSymbol) public {
        symbol = tSymbol;
        name = tName;
        decimals = 2;
        _totalSupply = 200000000 * 10**uint(decimals); // 200.000.000 tokens
        
        icoStartDate            = 1518480000;   // 2018/02/13
        
        roundEnd = [1519862400, 1521158400, 1523836800, 1525132800];
        roundTokenLeft = [10000000, 10000000, 30000000, 30000000];
        roundDiscount = [40, 30, 10, 0];
        
        tokenLockTime = 1572566400;     // 2019/11/01 after 18 months
        
        balances[owner] = _totalSupply;
        Transfer(address(0), owner, _totalSupply);
    }

    // ------------------------------------------------------------------------
    // Total supply
    // ------------------------------------------------------------------------
    function totalSupply() public constant returns (uint) {
        return _totalSupply  - balances[address(0)];
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
        var tokenCanBeBought = (msg.value*etherExRate*100).div(100-roundDiscount[round]);
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
            var neededEtherToBuy = (roundTokenLeft[round]*(100-roundDiscount[round])).div(etherExRate*100);
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

