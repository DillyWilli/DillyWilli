pragma solidity ^0.4.21;

///@title Sample Crypto Currency based on POW with features such as: configurable initial supply, transferable admin rights, 
/// coin transfer among users, non-negative balance, miner reward, coin minting etc.
///@author Ashay Maheshwari

contract admin{
	address public adminAddress;
	constructor() public{
		adminAddress=msg.sender;
	}

	modifier onlyAdmin(){
		if(msg.sender != adminAddress) revert();
		_;
	}

	function transferAdminRights(address _newAdmin) public onlyAdmin{
		adminAddress=_newAdmin;
	}
}

contract ACoin {

	mapping(address => uint256) public balanceOf; //query balance
	mapping(address => mapping(address => uint256)) public allowance; // represents the max amount to be transfered on behalf of someone


	string public standard = "ACoin v1.0";
	string public name;
	string public symbol;
	uint8 public decimalPoints;
	uint256 public totalSupply;
	event Transfer(address indexed from, address indexed to, uint256 value);// indexed puts the value in log memory not in contract data. 1st --> person who has allowed 


	constructor (uint256 initialSupply, string tokenName, string tokenSymbol, uint8 decimalUnit) public{
	
		balanceOf[msg.sender] =initialSupply;
		totalSupply = initialSupply;
		decimalPoints =decimalUnit;
		symbol=tokenSymbol;
		name=tokenName;
	}

	function transfer (address _to, uint256 _value) public{
		
		if(balanceOf[msg.sender]<_value) revert();	// check enough balance
		
		if(balanceOf[_to] + _value < balanceOf[_to]) revert(); //check overflow

		balanceOf[msg.sender] -= _value;
		balanceOf[_to] += _value;

		emit Transfer(msg.sender, _to, _value); //log the event
	}

	function approve(address _spender, uint256 _allowedAmount) public returns (bool success){
		allowance[msg.sender][_spender] =_allowedAmount;
		return true;
	}

	function transferFrom(address _from, address _to, uint256 _value) public returns (bool success){
		if(balanceOf[_from] < _value) revert();

		if(balanceOf[_to] + _value < balanceOf[_to]) revert();

		if(_value >allowance[_from][msg.sender]) revert();

		balanceOf[_from] -= _value;
		balanceOf[_to] += _value;

		allowance[_from][msg.sender] -=_value;

		emit Transfer(_from,_to,_value);
		return true;
	}

}

contract ACoinAdvanced is admin, ACoin{

	mapping (address => bool) public frozenAccount;
	uint256 public buyPrice;
	uint public sellPrice;
	uint minimumBalanceForAccount = 5 finney;

	event FrozenFund(address target, bool frozen);

	constructor(uint256 initialSupply, string tokenName, string tokenSymbol, uint8 decimalUnit, address centralAdmin) ACoin(0, tokenName, tokenSymbol, decimalUnit){
		totalSupply =initialSupply;
		if(centralAdmin != 0){
			 adminAddress=centralAdmin;
		 }
		 else{
		 	adminAddress=msg.sender;
		 }
		 balanceOf[adminAddress]=initialSupply;
	}

	function mint(address toAddress, uint256 mintAmount) public onlyAdmin{
		balanceOf[toAddress] += mintAmount;
		totalSupply += mintAmount;

		emit Transfer(0, this, mintAmount);
		emit Transfer(this, toAddress, mintAmount);
	}

	function freezeAccount(address target, bool status) onlyAdmin{
		frozenAccount[target] =status;
		emit FrozenFund(target,status);
	}

	function transferFrom(address _from, address _to, uint256 _value) public returns (bool success){

		if(frozenAccount[_from]) revert();

		if(balanceOf[_from] < _value) revert();

		if(balanceOf[_to] + _value < balanceOf[_to]) revert();

		if(_value >allowance[_from][msg.sender]) revert();

		balanceOf[_from] -= _value;
		balanceOf[_to] += _value;

		allowance[_from][msg.sender] -=_value;

		emit Transfer(_from,_to,_value);
		return true;
	}

		function transfer (address _to, uint256 _value) public{ 
		if(msg.sender.balance < minimumBalanceForAccount){
			sell((minimumBalanceForAccount - msg.sender.balance)/sellPrice);
		}
		if(frozenAccount[_to]) revert();
		if(balanceOf[msg.sender]<_value) revert();	// check enough balance
		
		if(balanceOf[_to] + _value < balanceOf[_to]) revert(); //check overflow

		balanceOf[msg.sender] -= _value;
		balanceOf[_to] += _value;

		emit Transfer(msg.sender, _to, _value); //log the event
	}

	function setPrices(uint _newSellPrice, uint _newBuyPrice) onlyAdmin{
		sellPrice = _newSellPrice;
		buyPrice = _newBuyPrice;
	}

	function buy() payable{
		uint amount = (msg.value/(1 ether)) / buyPrice;
		if(balanceOf[this] < amount)  revert();
		balanceOf[msg.sender] += amount;
		balanceOf[this] -= amount;
		emit Transfer(this, msg.sender, amount);

	}

	function sell(uint _amount){
		if(balanceOf[msg.sender] < _amount) revert();
		balanceOf[this] += _amount;
		balanceOf[msg.sender] -= _amount;
		
		if(!msg.sender.send(_amount*sellPrice*1 ether)){
			revert();
		}
		else {
			emit Transfer(msg.sender, this, _amount);
		}

	}

	function giveBlockReward(){
		balanceOf[block.coinbase] += 1;
	}

	bytes32 public currentChallange;
	uint public timeOfLastProof;
	uint public difficulty = 10**32;

	function proofOfWork(uint _nonce){
		bytes8 n = bytes8(sha3(_nonce, currentChallange));

		if(n < bytes8(difficulty)) revert();
		uint timeOfLastBlock = now - timeOfLastProof;
		if(timeOfLastBlock < 5 seconds) revert(); //too less time

		balanceOf[msg.sender] += timeOfLastBlock/60 seconds; // reward for every minute
		difficulty =difficulty *10 minutes/timeOfLastProof +1; //increase the difficulty
		timeOfLastProof =now;
		currentChallange = sha3(_nonce, currentChallange, block.blockhash(block.number -1));
	}
}
