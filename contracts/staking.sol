pragma solidity ^0.6.0;

import "./SafeMath.sol";
import "./SafeBEP20.sol";
import "./Ownable.sol";

contract Staking is Ownable {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;
    
    event Received(address, uint256);
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
    
    IBEP20 private connect;
    uint256 internal poolId;
    uint256 private ConnectStakingAlloc = 25000000000000000000;
    uint256 public nextHalving;
    uint256 investorID2;
    uint256 secondsInDay = 60;
    uint256 constant lockingPeriod = 60;
    address constant ConnectVault = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
    bool stakingStatus;

    
    
    mapping(uint256 => investors) public Investors;
    mapping(uint256 => pool) public poolData;
    mapping(address => bool) private whitelist;
    event AddedToWhitelist(address indexed account);
    event RemovedFromWhitelist(address indexed account);
    event addedToStaking(address indexed account, uint256 amount, uint256 _ID, uint256 _investmentTime, uint256 _releaseTime);
    event releasedStaking(address indexed account, uint256 _claimedBNB, uint256 _claimedConnect);
    event emergencyWithdrew(address indexed account, uint256 _accountID, uint256 _connect);
    
    
    struct investors {
        address payable user;
        uint256 weight;
        uint256 timeStamp;
        uint256 releaseTimeStamp;
        uint256 investorID;
        uint256 poolID2;
        bool claimed;
    }
    
    struct pool {
        uint256 startTimeStamp;
        uint256 endTimeStamp;
        uint256 stakeholders;
        uint256 balanceBNB;
        uint256 unclaimedBNB;
        uint256 balanceConnect;
        uint256 fundedConnect;
        uint256 stakingAlloc;
        uint256 unclaimedConnect;
        bool updated;
    }
    
    constructor(IBEP20 _connect) public {
        connect = _connect;
    }
    
     modifier restricted() {
            require(isWhitelisted(msg.sender));
        _;
    }
    
    function add(address _address) public onlyOwner {
        whitelist[_address] = true;
        emit AddedToWhitelist(_address);
    }
    
    function isWhitelisted(address _address) public view returns(bool) {
        return whitelist[_address];
    }
    
    //add only Whitelisted modifier here
    function updatePoolBalance(uint256 value) public restricted {
        require(stakingStatus == true, "Staking not started");
        if(poolData[poolId].endTimeStamp <= now) {
            updatePool();
            poolData[poolId].balanceBNB = poolData[poolId].balanceBNB.add(value);
            poolData[poolId].unclaimedBNB = poolData[poolId].unclaimedBNB.add(value);
        } else {
        poolData[poolId].balanceBNB = poolData[poolId].balanceBNB.add(value);
        poolData[poolId].unclaimedBNB = poolData[poolId].unclaimedBNB.add(value);
    } 
        }
        
    //updates next halving timestamp    
    function updateHalvingTimeStamp() private returns(bool success){
        if(nextHalving <= now) {
            ConnectStakingAlloc = ConnectStakingAlloc.div(2);
            nextHalving = nextHalving.add(secondsInDay.mul(70));
            poolData[poolId].stakingAlloc = poolData[poolId].stakingAlloc.add(ConnectStakingAlloc);
            return true;
        } else {
            return false;
        }
    }
    
    
    // fix this    
    function updatePool() private {
        if(poolData[poolId].endTimeStamp <= now) {
        poolId++;
        updateHalvingTimeStamp();
        poolData[poolId].startTimeStamp = now;
        poolData[poolId].endTimeStamp = now.add(lockingPeriod);
        poolData[poolId.sub(1)].updated = true;
    } else {
        poolData[poolId].updated = false;
    }
        
    }
    
    function deposit(uint256 _value) public {
        require(stakingStatus == true, "Staking is not started");
        investorID2++;
        if(poolData[poolId].endTimeStamp <= now) {
            updatePool();
            connect.safeTransferFrom(address(msg.sender), address(ConnectVault), _value);
            Investors[investorID2] = investors(msg.sender, _value, now, now.add(lockingPeriod), investorID2, poolId.add(1), false);
            poolData[poolId].stakeholders = poolData[poolId].stakeholders.add(1);
            
        } else {
        connect.safeTransferFrom(address(msg.sender), address(ConnectVault), _value);
        Investors[investorID2] = investors(msg.sender, _value, now, now.add(lockingPeriod), investorID2, poolId, false);
        poolData[poolId].stakeholders = poolData[poolId].stakeholders.add(1);
        poolData[poolId].balanceConnect = poolData[poolId].balanceConnect.add(_value);
        poolData[poolId].unclaimedConnect = poolData[poolId].unclaimedConnect.add(_value);
    }
        emit addedToStaking(msg.sender, _value, investorID2, now, now.add(lockingPeriod));
        }
        
    function emergencyWithdraw(uint256 _investorID) public {
        require(Investors[_investorID].user == msg.sender, "Only Investor can claim investment");
        require(Investors[_investorID].releaseTimeStamp >= now, "Tokens matured");
        require(Investors[_investorID].claimed == false, "Investment is already claimed");
        uint256 investorWeight = Investors[_investorID].weight;
        connect.safeTransferFrom(address(ConnectVault), address(msg.sender), investorWeight);
        poolData[Investors[_investorID].poolID2].balanceConnect = poolData[Investors[_investorID].poolID2].balanceConnect.sub(investorWeight);
        poolData[Investors[_investorID].poolID2].unclaimedConnect = poolData[Investors[_investorID].poolID2].unclaimedConnect.sub(investorWeight);
        Investors[_investorID].weight = 0;
        Investors[_investorID].claimed = true;
        emit emergencyWithdrew(msg.sender, _investorID, investorWeight);
    }    
        
    function vaultAllowance() private {
        connect.safeIncreaseAllowance(address(ConnectVault), ConnectStakingAlloc.mul(100));
    }    
    
    function start() public onlyOwner {
        require(stakingStatus == false);
        vaultAllowance();
        poolData[poolId].startTimeStamp = now;
        poolData[poolId].endTimeStamp = now.add(lockingPeriod);
        nextHalving = now.add(secondsInDay.mul(7)); //change this before deployment
        poolData[poolId].stakingAlloc = ConnectStakingAlloc;
        stakingStatus = true;
    }

    
    function shareOfThePool(uint256 _investorID) public view returns(uint256) {
        if (Investors[_investorID].claimed == true) {
            return 0;
        } else {
        return Investors[_investorID].weight.mul(1e12).div(poolData[Investors[_investorID].poolID2].balanceConnect);
    }
        
    }
    
    function getUnclaimedBalance(uint256 _investorID) private view returns(uint256) {
         return poolData[Investors[_investorID].poolID2].balanceBNB.mul(shareOfThePool(_investorID)).div(1e12);
    }
    
    function getUnclaimedConnect(uint256 _investorID) private view returns(uint256) {
        require(Investors[_investorID].claimed == false);
        uint256 stakingWeight = Investors[_investorID].weight;
        uint256 _fundedConnect = poolData[Investors[_investorID].poolID2].fundedConnect.mul(shareOfThePool(_investorID).div(1e12));
        uint256 unclaimed = poolData[Investors[_investorID].poolID2].stakingAlloc.mul(shareOfThePool(_investorID).div(1e12));
        uint256 result = _fundedConnect.add(unclaimed);
        return stakingWeight.add(result);
    }
    
    function getInvestorData(uint256 _investorID) public view returns(
        uint256 _investmentTimeStamp,
        uint256 _releaseTimeStamp,
        uint256 _weight,
        uint256 _share,
        uint256 _unclaimedBNB,
        uint256 _unclaimedConnect,
        bool _investmentClaimed) {
        if(Investors[_investorID].claimed == true) {
          _investmentTimeStamp = Investors[_investorID].timeStamp;
            return(_investmentTimeStamp, 0, 0, 0, 0, 0, true);
        } else {
        _investmentTimeStamp = Investors[_investorID].timeStamp;  
        _releaseTimeStamp = Investors[_investorID].releaseTimeStamp;
        _weight = Investors[_investorID].weight;
        _share = shareOfThePool(_investorID);
        _unclaimedBNB = getUnclaimedBalance(_investorID);
        _unclaimedConnect = getUnclaimedConnect(_investorID).sub(_weight);
        _investmentClaimed = Investors[_investorID].claimed;
        return(_investmentTimeStamp, _releaseTimeStamp, _weight, _share, _unclaimedBNB, _unclaimedConnect, _investmentClaimed);
        
    }
            
        }
    
    function updateAllowance(uint256 value) external {
        connect.safeIncreaseAllowance(address(this), value);
    }
    
    function realTimeUnclaimed(uint256 _investorID) public view returns(uint256 _connect, uint256 _bnb) {
        uint256 rewardPerSecBNB = getUnclaimedBalance(_investorID).div(lockingPeriod);
        uint256 rewardPerSecConnect = getUnclaimedConnect(_investorID).div(lockingPeriod);
        uint256 timeHeld = now.sub(Investors[_investorID].timeStamp);
        if(Investors[_investorID].claimed == true) {
            _connect = 0;
            _bnb = 0;
            return(_connect, _bnb);
        } 
        if(Investors[_investorID].releaseTimeStamp <= now) {
            _connect = getUnclaimedConnect(_investorID);
            _bnb = getUnclaimedBalance(_investorID);
           return(_connect, _bnb);
        } else {
            _connect = timeHeld.mul(rewardPerSecConnect);
            _bnb = timeHeld.mul(rewardPerSecBNB);
        return(_connect, _bnb);
        }
    }
    
    function claim(uint256 _investorID) external returns (bool success) {
        require(Investors[_investorID].claimed == false, "The reward was already claimed");
        require(Investors[_investorID].user == msg.sender, "Not Stakeholder");
        require(Investors[_investorID].releaseTimeStamp <= now, "Tokens did not mature");
        uint256 bnbToClaim = getUnclaimedBalance(_investorID);
        uint256 connectToClaim = getUnclaimedConnect(_investorID);
        Investors[_investorID].user.transfer(bnbToClaim);
        poolData[poolId].unclaimedBNB = poolData[poolId].unclaimedBNB.sub(bnbToClaim);
        connect.safeTransferFrom(address(ConnectVault), address(msg.sender), connectToClaim);
        poolData[Investors[_investorID].poolID2].unclaimedConnect = poolData[Investors[_investorID].poolID2].unclaimedConnect.sub(connectToClaim);
        Investors[_investorID].claimed = true;
        emit releasedStaking(msg.sender, bnbToClaim, connectToClaim);
        return true;
    }
}