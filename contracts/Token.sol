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

    string public name;
    string public symbol;
    uint8 public decimals;

    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) internal allowed;

    uint256 totalSupply_;

    uint public latestDifficultyPeriodStarted;
    uint public epochCount;

    uint public _BLOCKS_PER_READJUSTMENT = 1024;
    uint public  _MINIMUM_TARGET = 2**16;
    uint public  _MAXIMUM_TARGET = 2**234;

    uint public miningTarget;
    bytes32 public challengeNumber;

    uint public rewardEra = 0;
    uint public maxSupplyForEra;

    address public lastRewardTo;
    uint public lastRewardAmount;
    uint public lastRewardEthBlockNumber;

    mapping(bytes32 => bytes32) solutionForChallenge;

    uint public tokensMinted;

    event Mint(address indexed from, uint reward_amount, uint epochCount, bytes32 newChallengeNumber);

    function Token(string _name, string _symbol, uint8 _decimals, uint _totalSupply, uint _initialBalance, address _crowdFundingAddress) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        totalSupply_ = _totalSupply;

        balances[_crowdFundingAddress] = _initialBalance;
        tokensMinted += _initialBalance;

        maxSupplyForEra = _totalSupply.div(2);
        miningTarget = _MAXIMUM_TARGET;

        latestDifficultyPeriodStarted = block.number;

        _startNewMiningEpoch();
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

    function mint(uint256 nonce, bytes32 challenge_digest) public returns (bool success) {
        bytes32 digest =  keccak256(challengeNumber, msg.sender, nonce );

        if (digest != challenge_digest) revert();
        if (uint256(digest) > miningTarget) revert();

        bytes32 solution = solutionForChallenge[challengeNumber];
        solutionForChallenge[challengeNumber] = digest;
        if(solution != 0x0) revert();

        uint reward_amount = getMiningReward();

        balances[msg.sender] = balances[msg.sender].add(reward_amount);

        tokensMinted = tokensMinted.add(reward_amount);

        assert(tokensMinted <= maxSupplyForEra);

        lastRewardTo = msg.sender;
        lastRewardAmount = reward_amount;
        lastRewardEthBlockNumber = block.number;

        _startNewMiningEpoch();

        Mint(msg.sender, reward_amount, epochCount, challengeNumber );

        return true;
    }

    function _startNewMiningEpoch() internal {
        if (tokensMinted.add(getMiningReward()) > maxSupplyForEra && rewardEra < 39) {
            rewardEra = rewardEra + 1;
        }

        maxSupplyForEra = totalSupply_ - totalSupply_.div( 2**(rewardEra + 1));

        epochCount = epochCount.add(1);

        if (epochCount % _BLOCKS_PER_READJUSTMENT == 0) {
            _reAdjustDifficulty();
        }
        challengeNumber = block.blockhash(block.number - 1);
    }

    function _reAdjustDifficulty() internal {
        uint ethBlocksSinceLastDifficultyPeriod = block.number - latestDifficultyPeriodStarted;
        uint epochsMined = _BLOCKS_PER_READJUSTMENT;
        uint targetEthBlocksPerDiffPeriod = epochsMined * 60;

        if (ethBlocksSinceLastDifficultyPeriod < targetEthBlocksPerDiffPeriod) {
            uint excess_block_pct = (targetEthBlocksPerDiffPeriod.mul(100)).div( ethBlocksSinceLastDifficultyPeriod );
            uint excess_block_pct_extra = excess_block_pct.sub(100).limitLessThan(1000);
            miningTarget = miningTarget.sub(miningTarget.div(2000).mul(excess_block_pct_extra));
        } else {
            uint shortage_block_pct = (ethBlocksSinceLastDifficultyPeriod.mul(100)).div( targetEthBlocksPerDiffPeriod );
            uint shortage_block_pct_extra = shortage_block_pct.sub(100).limitLessThan(1000);
            miningTarget = miningTarget.add(miningTarget.div(2000).mul(shortage_block_pct_extra));
        }

        latestDifficultyPeriodStarted = block.number;

        if (miningTarget < _MINIMUM_TARGET) {
            miningTarget = _MINIMUM_TARGET;
        }

        if (miningTarget > _MAXIMUM_TARGET) {
            miningTarget = _MAXIMUM_TARGET;
        }
    }

    function getChallengeNumber() public constant returns (bytes32) {
        return challengeNumber;
    }

    function getMiningDifficulty() public constant returns (uint) {
        return _MAXIMUM_TARGET.div(miningTarget);
    }

    function getMiningTarget() public constant returns (uint) {
        return miningTarget;
    }

    function getMiningReward() public constant returns (uint) {
        return (50 * 10**uint(decimals) ).div( 2**rewardEra ) ;
    }

    function getMintDigest(uint256 nonce, bytes32 challenge_digest, bytes32 challenge_number) public view returns (bytes32 digesttest) {
        bytes32 digest = keccak256(challenge_number,msg.sender,nonce);
        return digest;
    }

    function checkMintSolution(uint256 nonce, bytes32 challenge_digest, bytes32 challenge_number, uint testTarget) public view returns (bool success) {
        bytes32 digest = keccak256(challenge_number,msg.sender,nonce);
        if(uint256(digest) > testTarget) revert();
        return (digest == challenge_digest);
    }
}