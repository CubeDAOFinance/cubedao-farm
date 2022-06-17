// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;
pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

import "./interfaces/IIFOPool.sol";
import "./interfaces/IIFOFactory.sol";
import "./interfaces/IValidator.sol";
import "./interfaces/IWCUBE.sol";

import "./interfaces/ICapswapV2Router02.sol";
import "./libraries/CapswapV2Library.sol";

contract IFOPool is IIFOPool{
	using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

	bool inited = false;
	bool settled = false;
	uint256 public raiseTotal;
	uint256 ONE_MONTH_TIME = 3600*24*30;
	address public factory;
	address public WCUBE;

	uint public lpTokenAmountA;
	uint public lpTokenAmountB;

	uint public refundSell;

	uint public treasure;

	uint256 public pid;
	address public initiator;
	bool 	public verified;
	address public sellToken;
	uint 	public sellAmount;
	address public raiseToken; 
	uint 	public raiseAmount;
	uint 	public startTimestamp;
	uint 	public endTimestamp;
	stakePeriod public period;
	string 	public metaData; // json string 

	// Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
    }

    mapping (address => UserInfo) public _userInfo;

    EnumerableSet.AddressSet users;
/*
    event Init(
    	uint _pid,
		address _initiator,
		address _sellToken,
		uint _sellAmount,
		address _raiseToken, 
		uint _raiseAmount,
		uint _startTimestamp,
		uint _endTimestamp,
		stakePeriod _period,
		string _metaData // json string 
	);
*/

	//event Verify(bool verified);
	event Deposit(address user,uint amount);
	event Quit(address user,uint amount);
	//event Claim(address user,uint reward,uint refund);
	//event Settled(uint raiseAmount,uint raiseTotal);
	//event InitLP(uint amountA, uint amountB, uint liquidity);
	//event RebalanceBuy(uint treasureAmount, uint boughtAmount);
	//event RebalanceSell(uint sellAmount, uint treasureAmount);
	//event UnlockLP(address user,uint lpAmount);
	//event ClaimTreasure(uint tokenAmount,uint treasureAmount);

	modifier onlyFactory{
		require(msg.sender == factory,'only factory');
		_;
	}

	modifier qualified(){
		address validator = IIFOFactory(factory).validator();
		require(IValidator(validator).qualified(msg.sender));
		_;
	}

	constructor(){
		factory = msg.sender;
		WCUBE = IIFOFactory(factory).WCUBE();
	}

	function init(
		uint _pid,
		address _initiator,
		address _sellToken,
		uint _sellAmount,
		address _raiseToken, 
		uint _raiseAmount,
		uint _startTimestamp,
		uint _endTimestamp,
		stakePeriod _period,
		string memory _metaData // json string 
	) override external onlyFactory{
		require(!inited,'inited');

		pid = _pid;
		initiator = _initiator;
		sellToken = _sellToken;
		sellAmount = _sellAmount;
		raiseToken = _raiseToken;
		raiseAmount = _raiseAmount;
		startTimestamp = _startTimestamp;
		endTimestamp = _endTimestamp;
		period = _period;
		metaData = _metaData;
		inited = true;
/*
		emit Init(
	    	_pid,
			_initiator,
			_sellToken,
			_sellAmount,
			_raiseToken, 
			_raiseAmount,
			_startTimestamp,
			_endTimestamp,
			_period,
			_metaData // json string 
		);
*/
	}

	receive() external payable {
        assert(msg.sender == WCUBE); // only accept CUBE via fallback from the WCUBE contract
    }

	function poolInfo() override external view returns (
		bool _verified,
		address _initiator,
		address _sellToken,
		uint _sellAmount,
		address _raiseToken, 
		uint _raiseAmount,
		uint _startTimestamp,
		uint _endTimestamp,
		stakePeriod _period,
		string memory _metaData, // json string 
		uint256 _userCount,
		uint256 _raiseTotal
	){
		return (
			verified,
			initiator,
			sellToken,
			sellAmount,
			raiseToken,
			raiseAmount,
			startTimestamp,
			endTimestamp,
			period,
			metaData,
			users.length(),
			raiseTotal
		);
	}

	function verify(bool _verified) override external onlyFactory{
		verified = _verified;
		//emit Verify(verified);
	}

	function userInfo(address user) override external view returns(uint256 amount){
		return _userInfo[user].amount;
	}

	function depositCUBE() override external payable qualified{
		require(block.timestamp < endTimestamp,'time end');

		UserInfo storage user = _userInfo[msg.sender];

		if(msg.value > 0){
			IWCUBE(WCUBE).deposit{value: msg.value}();
			assert(IWCUBE(WCUBE).transfer(address(this), msg.value));

			uint fee = calculateFee(msg.value);
			uint amount = msg.value.sub(fee);

	        user.amount = user.amount.add(amount);
	        raiseTotal = raiseTotal.add(amount);

	        IIFOFactory(factory).enter(pid,msg.sender);
	        users.add(msg.sender);

	        emit Deposit(msg.sender,amount);
        }

	}

	function deposit(uint256 amount) override external qualified{
		require(block.timestamp < endTimestamp,'time end');

		UserInfo storage user = _userInfo[msg.sender];
		if(amount > 0){
			IERC20(raiseToken).safeTransferFrom(address(msg.sender), address(this), amount);

			uint fee = calculateFee(amount);
			amount = amount.sub(fee);

			user.amount = user.amount.add(amount);
			raiseTotal = raiseTotal.add(amount);

			IIFOFactory(factory).enter(pid,msg.sender);
	        users.add(msg.sender);

	        emit Deposit(msg.sender,amount);
		}

	}

	function quit(uint256 amount) override external qualified{
		require(block.timestamp < endTimestamp,'time end');

		UserInfo storage user = _userInfo[msg.sender];
		require(amount <= user.amount,'not enough amount');

		if(amount == 0){
			return;
		}

		user.amount = user.amount.sub(amount);
		raiseTotal = raiseTotal.sub(amount);
		uint fee = calculateFee(amount);

		amount = amount.sub(fee);
		if(raiseToken == WCUBE){
			IWCUBE(WCUBE).withdraw(amount);
        	safeTransferCUBE(address(msg.sender), amount);
		}
		else{
			IERC20(raiseToken).transfer(msg.sender, amount);
		}

		if(user.amount == 0){
			IIFOFactory(factory).quit(pid,msg.sender);
	        users.remove(msg.sender);
		}

		emit Quit(msg.sender,amount);

	}

	function calculateFee(uint amount) internal returns(uint fee){
		address feeTo = IIFOFactory(factory).feeTo();
		fee = feeTo == address(0)?0:amount.mul(IIFOFactory(factory).ifoFeeRate()).div(10000);
		if(fee > 0){
			IERC20(raiseToken).transfer(feeTo, fee);
		}
	}

	function claim() override external{
		require(block.timestamp > endTimestamp,'can not claim');
		if(!settled){
			settled = true;
			settle();
			initlp();
			refundGas();
		}
		UserInfo storage user = _userInfo[msg.sender];

		(uint reward,uint refund) = consult(user.amount,raiseTotal);

		if(reward > 0){
			IERC20(sellToken).transfer(msg.sender, reward);
		}
		if(refund > 0){
			if(raiseToken == WCUBE){
				IWCUBE(WCUBE).withdraw(refund);
	        	safeTransferCUBE(address(msg.sender), refund);
			}
			else{
				IERC20(raiseToken).transfer(msg.sender, refund);
			}
		}

		//emit Claim(msg.sender,reward,refund);
	}

	function settle() internal{
		uint excessRate = IIFOFactory(factory).excessRate();
		uint topLimit = raiseAmount.mul(100+excessRate).div(100);

		if (raiseTotal < raiseAmount){
			lpTokenAmountA = raiseTotal;
			lpTokenAmountB = sellAmount.mul(raiseTotal).div(raiseAmount);
			
			refundSell = IERC20(sellToken).balanceOf(address(this)).sub(lpTokenAmountB*2);
			IERC20(sellToken).transfer(initiator,refundSell);
		}
		else{
			lpTokenAmountA = raiseAmount;
			lpTokenAmountB = sellAmount;
			
			treasure = raiseTotal > topLimit ? topLimit.sub(raiseAmount) : raiseTotal.sub(raiseAmount);
		}

		//emit Settled(raiseAmount,raiseTotal);

	}

	function initlp() internal{
		// make lpPair
		address swapRouter = IIFOFactory(factory).swapRouter();

		IERC20(sellToken).approve(swapRouter,lpTokenAmountA);
		IERC20(raiseToken).approve(swapRouter,lpTokenAmountB);
		//(uint amountA, uint amountB, uint liquidity) = 
		ICapswapV2Router02(swapRouter).addLiquidity(raiseToken, sellToken,lpTokenAmountA,lpTokenAmountB,0,0,address(this),block.timestamp+60);

		//emit InitLP(amountA,amountB,liquidity);
	}

	function refundGas() internal{
		address openfeeToken = IIFOFactory(factory).openfeeToken();
		uint openfeeAmount = IIFOFactory(factory).openfeeAmount();
		IERC20(openfeeToken).transfer(msg.sender, openfeeAmount);
	}

	function consult(uint _amount,uint _raiseTotal) public view returns(uint reward,uint refund){
		uint excessRate = IIFOFactory(factory).excessRate();
		if(_raiseTotal <= raiseAmount.mul(100+excessRate).div(100)){
			reward = _amount.mul(sellAmount).div(raiseAmount);
		}
		else{
			uint sellTotal = sellAmount.mul(100+excessRate).div(100);
			uint refundTotal = _raiseTotal.sub(raiseAmount.mul(100+excessRate).div(100));
			reward = _amount.mul(sellTotal).div(_raiseTotal);
			refund = _amount.mul(refundTotal).div(_raiseTotal);
		}
	}

	function pending(address _user) override external view returns (uint reward,uint refund){
		UserInfo storage user = _userInfo[_user];
		(reward,refund) = consult(user.amount,raiseTotal);
	}

	function rebalance() override external{
		require(settled,'not settled');
		address swapFactory = IIFOFactory(factory).swapFactory();
		address lpPair = CapswapV2Library.pairFor(swapFactory,sellToken, raiseToken);
		(uint reserveSell,uint reserveRaise) = CapswapV2Library.getReserves(swapFactory,sellToken,raiseToken);

		uint raise = CapswapV2Library.quote(sellAmount,reserveSell,reserveRaise);
		if(raise < raiseAmount.mul(8).div(10)){
			// buy sellToken user treasure
			uint validTreasure = treasure.div(10);
			if(validTreasure > 0){
				treasure = treasure.sub(validTreasure);

				uint amountOut = CapswapV2Library.getAmountOut(validTreasure,reserveRaise,reserveSell);

				(address token0,) = CapswapV2Library.sortTokens(raiseToken, sellToken);
				(uint amount0Out, uint amount1Out) = raiseToken == token0 ? (uint(0), amountOut) : (amountOut, uint(0));

				IERC20(raiseToken).transfer(lpPair,validTreasure);
				ICapswapV2Pair(lpPair).swap(amount0Out, amount1Out, address(this), new bytes(0));

				//emit RebalanceBuy(validTreasure,amountOut);
			}
		}
		if(raise > raiseAmount.mul(15).div(10)){
			// sell sellToken to treasure
			uint validSellTokenAmount = IERC20(sellToken).balanceOf(address(this)).div(10);
			if(validSellTokenAmount > 0){
				uint amountOut = CapswapV2Library.getAmountOut(validSellTokenAmount,reserveSell,reserveRaise);

				treasure = treasure.add(amountOut);

				(address token0,) = CapswapV2Library.sortTokens(raiseToken, sellToken);
				(uint amount0Out, uint amount1Out) = raiseToken == token0 ? (amountOut, uint(0)) : (uint(0), amountOut);

				IERC20(sellToken).transfer(lpPair,validSellTokenAmount);
				ICapswapV2Pair(lpPair).swap(amount0Out, amount1Out, address(this), new bytes(0));

				//emit RebalanceSell(validSellTokenAmount,amountOut);
			}
		}
	}

	// for initiator

	function unlockLiquidity() override external{
		require(msg.sender == initiator,'only initiator');
		require(block.timestamp > endTimestamp.add(ONE_MONTH_TIME.mul(uint(period)+1)),'unlock later');

		address swapFactory = IIFOFactory(factory).swapFactory();
		address lpToken = CapswapV2Library.pairFor(swapFactory,sellToken, raiseToken);
		uint256 lpBalance = IERC20(lpToken).balanceOf(address(this));
		IERC20(lpToken).transfer(initiator,lpBalance);

		//emit UnlockLP(initiator,lpBalance);
	}

	function treasurePending() override external view returns(uint256 sellTokenAmount, uint256 raiseTokenAmount){
		if(settled){
			sellTokenAmount = IERC20(sellToken).balanceOf(address(this));
			raiseTokenAmount = treasure;
		}

	}
 	function claimTreasure() override external{
 		require(msg.sender == initiator,'only initiator');
		require(block.timestamp > endTimestamp.add(ONE_MONTH_TIME.mul(uint(period)+1)),'unlock later');

		uint sellTokenAmount = IERC20(sellToken).balanceOf(address(this));
		if(sellTokenAmount > 0){
			IERC20(sellToken).transfer(msg.sender,sellTokenAmount);
		}
		if(treasure > 0){
			if(raiseToken == WCUBE){
				IWCUBE(WCUBE).withdraw(treasure);
	        	safeTransferCUBE(address(msg.sender), treasure);
			}
			else{
				IERC20(raiseToken).transfer(msg.sender, treasure);
			}
		}

		//emit ClaimTreasure(sellTokenAmount,treasure);

 	}

	function safeTransferCUBE(address to, uint256 value) internal {
        (bool success, ) = to.call{gas: 23000, value: value}("");
        // (bool success,) = to.call{value:value}(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }

}