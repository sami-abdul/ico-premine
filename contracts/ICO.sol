pragma solidity ^0.4.21;

import "./SafeMath.sol";
import "./Token.sol";
import "./Repository.sol";
import "./Ownable.sol";

contract ICO is Ownable, Repository {
    using SafeMath for uint256;

    uint constant public TOKEN_SUPPLY = 100000000;
    uint constant public CROWD_FUNDING_SHARE = 15000000;
    uint constant public TEAM_SHARE = 15000000;

    uint constant public SALE_OPEN_DATE = 1525419946;
    uint constant public FUNDS_UNLOCK_DATE = SALE_OPEN_DATE + 60 days;

    uint lastBlock;
    uint blockReward = 5;

    uint tokensSold = 0;

    ERC223 public token;
    address public wallet = 0x9D9C605fF54425876Cda6AE3BD4c2c408A713bf1;
    uint256 public rate = 1000;
    uint256 public weiRaised = 0;

    event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
    event TokenAmount(uint256 indexed amount);

    constructor() public {
        lastBlock = block.number;

        team.push(TeamMember(0x8b760F272a996f834F7408403e507401DD954dD4, 30));
        team.push(TeamMember(0x617d1326a7ae1df47510242e07dbf3f0e0ac4d63, 30));
        team.push(TeamMember(0x76b741db5b2763c55a3d7458fc646caa14e9372c, 20));
        team.push(TeamMember(0x90110ffc4937dcdbb8c386c1e18cb2c1f1ba9f8a, 10));
        team.push(TeamMember(0x54cA715a29a694bF837F5F2b74163B07Ad3F3E8b, 10));

        token = new Token("Token", "TKN", 8, TOKEN_SUPPLY, CROWD_FUNDING_SHARE + TEAM_SHARE, address(this));
    }

    function getBalance() public view returns (uint) {
        return token.balanceOf(msg.sender);
    }

    modifier onlyAfterCrowdFundingOpens {
        require(SALE_OPEN_DATE >= block.timestamp);
        _;
    }

    modifier onlyAfterFundsUnlock {
        require(FUNDS_UNLOCK_DATE >= block.timestamp);
        _;
    }

    function () external payable {
        buyTokens(msg.sender);
    }

    function distributeTokensToTeam() public onlyOwner onlyAfterFundsUnlock {
        uint16 totalShare = 0;
        for (uint i = 0; i < team.length; i++) {
            totalShare += team[i].percent;
        }
        require (totalShare == 100);

        for (uint j = 0; j < team.length; j++) {
            token.transfer(team[j].wallet, (team[j].percent / 100) * TEAM_SHARE);
        }
    }

    function buyTokens(address _beneficiary) public onlyAfterCrowdFundingOpens payable {
        uint256 weiAmount = msg.value;
        _preValidatePurchase(_beneficiary, weiAmount);

        uint256 tokens = _getTokenAmount(weiAmount);

        require (tokensSold + tokens <= CROWD_FUNDING_SHARE);

        weiRaised = weiRaised.add(weiAmount);
        tokensSold += tokens;

        _processPurchase(_beneficiary, tokens);
        emit TokenPurchase(
        msg.sender,
        _beneficiary,
        weiAmount,
        tokens
        );

        _forwardFunds();
    }

    function _preValidatePurchase(address _beneficiary, uint256 _weiAmount) internal pure {
        require(_beneficiary != address(0));
        require(_weiAmount != 0);
    }

    function _deliverTokens(address _beneficiary, uint256 _tokenAmount) internal onlyAfterCrowdFundingOpens {
        token.transfer(_beneficiary, _tokenAmount);
    }

    function _processPurchase(address _beneficiary, uint256 _tokenAmount) internal {
        _deliverTokens(_beneficiary, _tokenAmount);
    }

    function _getTokenAmount(uint256 _weiAmount) internal view returns (uint256) {
        uint256 etherAmount = _weiAmount / 1000000000000000000;
        return etherAmount.mul(rate);
    }

    function _forwardFunds() internal {
        wallet.transfer(msg.value);
    }
}
