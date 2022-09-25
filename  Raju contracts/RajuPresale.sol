pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Crowdsale
 * @dev Crowdsale is a base contract for managing a token crowdsale,
 * allowing investors to purchase tokens with ether. This contract implements
 * such functionality in its most fundamental form and can be extended to provide additional
 * functionality and/or custom behavior.
 * The external interface represents the basic interface for purchasing tokens, and conform
 * the base architecture for crowdsales. They are *not* intended to be modified / overridden.
 * The internal interface conforms the extensible and modifiable surface of crowdsales. Override
 * the methods to add functionality. Consider using 'super' where appropriate to concatenate
 * behavior.
 */
 contract RajuPresale is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;

    bool public isPresaleOpen = false;
    bool public isList = true;

    // buyers infos
    struct preBuy {
        uint usdcAmount;
        uint pTokenAmount;
        uint pTokenClaimedAmount;
    }
    mapping (address => preBuy) public preBuys;
    mapping(address=>bool) public whiteListed;
    mapping(address => uint256) private paidTotal;
    mapping(address => bool) public bought;
    mapping(address => address) public referralAccount;
    // pToken address
    ERC20 public pToken;
    // address where funds are collected
    address public wallet;
    // address of usdc stablecoin
    ERC20 public usdc;
    // buy rate
    uint public rate1;
    uint public rate2;
    // amount of wei raised
    uint public usdcRaised;
    // total amount (max) of pToken token that buyers can redeem
    uint public totalpTokenAmountToDistribute;

    uint public immutable RATE_DECIMALS = 10 ** 18;
    uint public immutable REBASE_DECIMALS = 10 ** 18;
    uint public immutable USDC_DECIMALS = 10 ** 6;

    // buy
    uint256 public minUsdcBuy;
    uint256 public maxUsdcBuy;
    // sell
    uint256 public minTokenSell;
    uint256 public maxTokenSell;

    uint256[3] public startTimes;
    uint256[3] public periods;
    uint256[3] public rebaseRates;
    uint256 public dailyRate;
    uint256 public referralRate;

    address[] public buyerAccounts;

    event TokenPurchase(
        address indexed purchaser,
        uint256 usdcAmount,
        uint256 pTokenAmount
    );

    event TokenSold(
        address indexed solder,
        uint256 pTokenAmount,
        uint256 usdcAmount
    );

    event SetDailyRate(uint dailyRate);
    event SetMinBuy(uint);
    event SetMaxBuy(uint);
    event SetMinSell(uint);
    event SetMaxSell(uint);

    modifier onlyToken() {
        require(msg.sender == address(pToken), "error: Caller is not pToken!");
        _;
    }

    constructor(uint256 _rate1, uint256 _rate2, address _wallet, ERC20 _usdc, ERC20 _pToken) {
        require(_rate1 > 0);
        require(_rate2 > 0);
        require(_wallet != address(0));
        require(address(_usdc) != address(0));
        require(address(_pToken) != address(0));
                            
        rate1 = _rate1;
        rate2 = _rate2;
        wallet = _wallet;
        usdc = _usdc;
        pToken = _pToken;
    }

    function setWallet(address _wallet) external onlyOwner {
        wallet = _wallet;
    }

    function setReferralRate(uint256 _referralRate) external onlyOwner {
        referralRate = _referralRate;
    }

    function setPresaleTokenAddress(address _pTokenAddress) external onlyOwner {
        pToken = ERC20(_pTokenAddress);
    }

    function startPresale() external onlyOwner {
        require(!isPresaleOpen, "Presale is open");
        
        isPresaleOpen = true;
    }

    function setList(bool _isList) external onlyOwner {
        require(!isPresaleOpen, "Presale is open");

        isList = _isList;
    }

    function closePrsale() external onlyOwner {
        require(isPresaleOpen, "Presale is not open yet.");
        
        isPresaleOpen = false;
    }

    function setWhitelist(address[] memory addresses, bool value) public onlyOwner{
        require(isList, "Whitelist disable");
        for (uint i = 0; i < addresses.length; i++) {
            whiteListed[addresses[i]] = value;
        }
    }

    function setRate1(uint256 _rate1) external onlyOwner {
        rate1 = _rate1;    
    }

    function setRate2(uint256 _rate2) external onlyOwner {
        rate2 = _rate2;    
    }

    // allows buyers to put their usdc to get some pToken once the presale will closes
    function buy(uint _amount, address ref) public {
        require(isPresaleOpen, "Presale is not open yet");
        require(_amount >= minUsdcBuy, "You need to buy at least some min amount");
        require(_amount < maxUsdcBuy, "Selected amount exceeds maxLimit.");
        require(_amount <= usdc.balanceOf(msg.sender), "There is no enough USDC in your wallet.");
        require(paidTotal[msg.sender] + _amount <= maxUsdcBuy);
        require((block.timestamp >= startTimes[0] && block.timestamp < (startTimes[0] + periods[0])) || 
                (block.timestamp >= startTimes[1] && block.timestamp < (startTimes[1] + periods[1])), 
                "Presale has not yet opened or is already closed.");

        if (whiteListed[ref])
            whiteListed[msg.sender] = true;

        require(isList == false || whiteListed[msg.sender] == true, "error: Not whitelisted!");

        // calculate pToken amount to be created
        uint256 pTokenAmount;
        if(block.timestamp >= startTimes[0] && block.timestamp < (startTimes[0] + periods[0]))
        {
            pTokenAmount = _amount.mul(RATE_DECIMALS).div(rate1).mul(10 ** 12);
        }
        else if(block.timestamp >= startTimes[1] && block.timestamp < (startTimes[1] + periods[1]))
        {
            pTokenAmount = _amount.mul(RATE_DECIMALS).div(rate2).mul(10 ** 12);
        }

        if (!bought[msg.sender]) {
            buyerAccounts.push();
            bought[msg.sender] = true;
        }

        if (ref != msg.sender && ref != address(0))
            referralAccount[msg.sender] = ref;

        require(pToken.balanceOf(address(this)) >= pTokenAmount, "There is no enough PToken.");
        // safe transferFrom of the payout amount
        usdc.safeTransferFrom(msg.sender, address(this), _amount);
        pToken.safeTransfer(msg.sender, pTokenAmount);
        if (referralAccount[msg.sender] != address(0))
            pToken.safeTransfer(referralAccount[msg.sender], pTokenAmount.mul(referralRate).div(100));

        // update state
        usdcRaised = usdcRaised.add(_amount);
        totalpTokenAmountToDistribute = totalpTokenAmountToDistribute.add(pTokenAmount);
        require(pToken.balanceOf(address(this)) >= totalpTokenAmountToDistribute, "there aren't enough fund to buy more pToken");

        preBuys[msg.sender].usdcAmount = preBuys[msg.sender].usdcAmount.add(_amount);
        preBuys[msg.sender].pTokenAmount = preBuys[msg.sender].pTokenAmount.add(pTokenAmount); 
        paidTotal[msg.sender] = paidTotal[msg.sender].add(_amount);
        emit TokenPurchase(
            msg.sender,
            _amount,
            pTokenAmount
        );
    }

    function sell(uint _amount) public {
        require(isList == false || whiteListed[msg.sender] == true);
        require(_amount >= minTokenSell, "You need to sell at least some min amount");
        require(_amount < maxTokenSell, "Selected amount exceeds maxLimit.");
        require(_amount <= pToken.balanceOf(msg.sender), "There is no enough pToken in your wallet.");
        require((block.timestamp >= startTimes[1] && block.timestamp < (startTimes[1] + periods[1])), "You can't sell at this step.");

        // calculate pToken amount to be created
        uint256 usdcAmount;
        if(block.timestamp >= startTimes[1] && block.timestamp < (startTimes[1] + periods[1]))
        {
            usdcAmount = _amount.mul(rate2).div(RATE_DECIMALS).div(10 ** 12);
        }

        require(usdc.balanceOf(address(this)) >= usdcAmount, "There is no enough USDC.");
        // safe transferFrom of the payout amount
        pToken.safeTransferFrom(msg.sender, address(this), _amount);
        usdc.safeTransfer(msg.sender, usdcAmount);
        
        emit TokenSold(
            msg.sender,
            _amount,
            usdcAmount
        ); 
    }

    function getPercentReleased() public view returns (uint released) {
        // if the presale isn't finish
        if (block.timestamp <= startTimes[2]) {
        return 30;
        } 
        else if (block.timestamp > startTimes[2]) { // already 100% released
            released = 30 + dailyRate.mul(block.timestamp - startTimes[2]).div(86400);
            if (released >= 100) 
                return 100;
            return released;
        } 
    }

    function getClaimableAmount(address _account) public view returns (uint) {
        require(!isPresaleOpen, "Presale is not over yet");
        uint percentReleased = getPercentReleased();

        uint totalpTokenToClaim = preBuys[_account].pTokenAmount.mul(percentReleased).div(100);
        uint pTokenToClaim = totalpTokenToClaim.sub(preBuys[_account].pTokenClaimedAmount);
        return pTokenToClaim;
    }

    function getDepositedAmount(address _account) public view returns (uint) {
        uint usdcAmount = preBuys[_account].usdcAmount;
        return usdcAmount;
    }
    
    function update() public onlyToken {
        uint256 rebaseRate = getRebaseRate(block.timestamp);
        for (uint i;i < buyerAccounts.length; i++) {
            preBuys[buyerAccounts[i]].pTokenAmount = preBuys[buyerAccounts[i]].pTokenAmount.mul(rebaseRate).div(REBASE_DECIMALS);
            preBuys[buyerAccounts[i]].pTokenClaimedAmount = preBuys[buyerAccounts[i]].pTokenClaimedAmount.mul(rebaseRate).div(REBASE_DECIMALS);
        }
    }

    function getRebaseRate(uint time) public view returns (uint rebaseRate) {
        if((time >= startTimes[0]) && (time < startTimes[0] + periods[0])) {
            return rebaseRates[0];
        } else if((time >= startTimes[1]) && (time < startTimes[1] + periods[1])) {
            return rebaseRates[1];
        } else if((time >= startTimes[2]) && (time < startTimes[2] + periods[2])) {
            return rebaseRates[2];
        } else {
            return 1;
        }
    }

    function claim() public {
        // require(!isPresaleOpen, "Presale is not over yet");
        require(isList == false || whiteListed[msg.sender] == true);
        uint percentReleased = getPercentReleased();
        uint totalpTokenToClaim = preBuys[msg.sender].pTokenAmount.mul(percentReleased).div(100);
        uint pTokenToClaim = totalpTokenToClaim.sub(preBuys[msg.sender].pTokenClaimedAmount);
        preBuys[msg.sender].pTokenClaimedAmount = preBuys[msg.sender].pTokenClaimedAmount.add(pTokenToClaim);
        totalpTokenAmountToDistribute = totalpTokenAmountToDistribute.sub(pTokenToClaim);
        pToken.safeTransfer(msg.sender, pTokenToClaim);
    }

    // allows operator wallet to get the usdc deposited in the contract
    function retreiveUSDC(uint _amount) public {
        require(msg.sender == wallet);
        usdc.safeTransfer(wallet, _amount);
    }

    // allows operator wallet to retreive the pToken that won't be distributed
    function retreiveExcesspToken() public {
        require(msg.sender == wallet);
        require(!isPresaleOpen, "Presale is not over yet");
        pToken.safeTransfer(wallet, pToken.balanceOf(address(this)).sub(totalpTokenAmountToDistribute));
    }

    function setPhaseSetting(uint index, uint256 _sTime, uint256 _period, uint256 _rebaseRate) external onlyOwner {
        require( (startTimes[index] == 0 || startTimes[index] >= block.timestamp) && 
                (_sTime >= block.timestamp),  
                "error: Invalid arguments!");
        startTimes[index] = _sTime;
        periods[index] = _period;
        rebaseRates[index] = _rebaseRate;
    }

    function setDailyRate(uint256 _dailyRate) external onlyOwner {
        require(startTimes[0] > block.timestamp, "Presale has already started.");
        require(_dailyRate > 0, "Dailyamount should greater than zero.");
        dailyRate = _dailyRate;
        emit SetDailyRate(_dailyRate);
    }

    function setMinBuy(uint256 _minUsdc) external onlyOwner {
        require(_minUsdc > 0);
        minUsdcBuy = _minUsdc;
        emit SetMinBuy(_minUsdc);
    }

    function setMaxBuyUsdc(uint256 _maxUsdc) external onlyOwner {
        require(_maxUsdc > 0);
        maxUsdcBuy = _maxUsdc;
        emit SetMaxBuy(_maxUsdc);
    }

    function setMinSellToken(uint256 _minToken) external onlyOwner {
        require(_minToken > 0);
        minTokenSell = _minToken;
        emit SetMinSell(_minToken);
    }

    function setMaxSellToken(uint256 _maxToken) external onlyOwner {
        require(_maxToken > 0);
        maxTokenSell = _maxToken;
        emit SetMaxSell(_maxToken);
    }
}