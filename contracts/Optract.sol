pragma solidity ^0.5.2;
import "./SafeMath.sol";
import "./RegistryInterface.sol";
import "./ERC20.sol";
import "./BlockRegistryInterface.sol";

/*
roles:
   * originalOwner: someone want to buy the right of some ETH, pay DAI to ethSeller
   * ethSeller: someone want to sell the rights of some ETH, fill in ETH to this contract
   * buyer: someone want to buy the ownership of those ETH, pay DAI to currentOwner and become new owner
            (originalOwner is the first buyer)
time:
   * `period`: in order of months
   * the new contract owner cannot sell the ownership right away
*/

contract Optract {
    using SafeMath for uint256;
    address public originalOwner;
    address public currentOwner;
    address public ethSeller;
    address public registryAddr;  // the contract registry
    address public blkAddr;  // the side-chain address
    address public currencyTokenAddr;
    uint256 public ethAmount;
    uint256 public totalPriceInDai;
    uint256 public optionPrice;
    uint256 public actionTime;  // right now, the actions are contract creation and newOwner()
    uint256 public sblockTimeStep;
    uint256 public period;  // length of time
    bool public onStock;
    bool public expired = false;  // query "registry" to determine when to expire
    bool public exercised = false;

    // decide who and when can claimOptract(); update when claimOptract(), reset when putOnStock()
    address public lastOwner;
    uint256 public lastSblockNo = 0;  // `SblockNo` stand for sideblock number
    uint256 public lastOprice = 0;  // `Oprice` stand for option price

    constructor (
        uint256 _ethAmount,
        uint256 _totalPriceInDai,
        uint256 _optionPrice,
        address _registryAddr,
        address _originalOwner,
        address _blkAddr,
        address _currencyTokenAddr
    ) public {
        ethAmount = _ethAmount;
        totalPriceInDai = _totalPriceInDai;
        optionPrice = _optionPrice;
        registryAddr = _registryAddr;
        originalOwner = _originalOwner;
        blkAddr = _blkAddr;
        currencyTokenAddr = _currencyTokenAddr;

        onStock = true;  // for others to query
        currentOwner = _originalOwner;
        actionTime = block.timestamp;  // use this to avoid some too soon operations
        // sblockTimeStep = iBlockRegistry(blkAddr).getSblockTimeStep();
        sblockTimeStep = 2 minutes;  // use a small value for debug purpose
    }

    modifier ownerOnly() {
        require(msg.sender == currentOwner, "not owner");
        _;
    }

    modifier ethFilled() {
        require (ethSeller != address(0) && address(this).balance > 0);
        _;
    }

    modifier isOnStock() {
        require(onStock == true, "not on stock");
        _;
    }

    modifier whenExpired() {
        require(iOptractRegistry(registryAddr).isExpired(address(this)) == true, "can no longer excercise");
        _;
    }

    modifier whenNotExpired() {
        require(iOptractRegistry(registryAddr).isExpired(address(this)) == false, "now can excercise");
        _;
    }

    // modifier whenLastExerciseChance() {
    //     uint256 expireTime = iOptractRegistry(registryAddr).getExpireTime();
    //     require(block.timestamp >= expireTime - 8 hours && block.timestamp < expireTime);
    //     _;
    // }

    modifier whenBeforeLastExerciseChance() {
        uint256 expireTime = iOptractRegistry(registryAddr).getExpireTime();
        require(block.timestamp < expireTime - 8 hours);
        _;
    }

    modifier whenCanExercise() {
        uint256 expireTime = iOptractRegistry(registryAddr).getExpireTime();
        require((onStock == false && block.timestamp < expireTime)
                || (block.timestamp >= expireTime - 8 hours && block.timestamp < expireTime)
               );
        _;
    }

    // after construct, need a ethSeller to fill in ETH, and the ethSeller obtain DAI
    function fillInEth() public payable whenNotExpired {
        require(ethSeller == address(0), "others fill ETH already");  // only one can fill in ETH
        require(msg.value == ethAmount, "need to deposit exact amount of ETH");
        ethSeller = msg.sender;
        actionTime = block.timestamp;
        onStock = false;
        // address(this) get 5 DAI (the fix optionPrice for 1st trade) from originalOwner in 'Registry' contract
        ERC20(currencyTokenAddr).transfer(msg.sender, optionPrice);
        // note: the originalOwner can hold for some time then withdraw or putOnStock() at some point
    }

    // consider: gap of 'actionTime' should > 15 min = sidechain block time = 'sblockTimeStep'
    // consider: setNewOptionPrice() only accept a lower optionPrice
    // consider: claimOptract can call by: 1: option Buyers (once sideblock finished, there one real winner), 2: option seller, 3: 11BE
    // cnosider: add a mapping or variable to record claimed price of a sideblockNo (sbNo)
    //           if same sbNo, the price must larger; otherwise, current sbNo must > previous sbNo with a claimed price

    // a successful buyer can get the ownership (verified through state channel)
    function claimOptract(
        bytes32[] memory proof,
        bool[] memory isLeft,
        bytes32 targetLeaf,
        bytes32 merkleRoot,
        uint256 bidPrice
    ) public ethFilled whenBeforeLastExerciseChance returns(bool) {
        // verify:  require(calculateLeaf(msg.sender, some_more_data...) == targetLeaf))
        require(iBlockRegistry(blkAddr).merkleTreeValidator(proof, isLeft, targetLeaf, merkleRoot) == true, "invalid Merkle Proof");
	require(ERC20(currencyTokenAddr).allowance(msg.sender, address(this)) >= bidPrice + bidPrice/500);
	require(bidPrice > optionPrice);  // todo: bidPrice > optionPrice && bidPrice - optionPrice > 0.01 Ether
        uint256 sblockNo = iBlockRegistry(blkAddr).getSblockNo();

        // new owner; the ownership could transfer several times in one sblockNo
        if (onStock == true && lastSblockNo == 0 && lastOprice == 0) {  // for first one who claim during current sblockNo
            onStock = false;
            lastOwner = currentOwner;  // the owner before this sblockNo
            lastSblockNo = sblockNo;

            lastOprice = bidPrice;
            currentOwner = msg.sender;
            actionTime = block.timestamp;

            ERC20(currencyTokenAddr).transferFrom(msg.sender, lastOwner, bidPrice);
            ERC20(currencyTokenAddr).transferFrom(msg.sender, blkAddr, bidPrice/500);  // 0.2% fee to block contract
        } else if (onStock == false && bidPrice > lastOprice && sblockNo == lastSblockNo) {  // happen when second buyer coming in same sblock
            // in same sblock, highest bid win the contract, and the prevBidder get money back
            address prevBidder = currentOwner;
            uint256 prevBidPrice = lastOprice;

            lastOprice = bidPrice;
            currentOwner = msg.sender;
            actionTime = block.timestamp;

            ERC20(currencyTokenAddr).transferFrom(msg.sender, prevBidder, prevBidPrice);
            ERC20(currencyTokenAddr).transferFrom(msg.sender, lastOwner, bidPrice - prevBidPrice);
            ERC20(currencyTokenAddr).transferFrom(msg.sender, blkAddr, bidPrice/500);  // 0.2% fee to block contract
        } else {
            revert();
        }
        optionPrice = bidPrice;
        return true;
    }

    function putOnStock(uint256 _newOptionPrice) public ethFilled ownerOnly whenBeforeLastExerciseChance {
        // call it when a buyer want to sell the option
        require(onStock == false, "can only put on Stock once");
        require(_newOptionPrice >= iOptractRegistry(registryAddr).queryOptionMinPrice());  // at least 5 DAI
        // require(block.timestamp > actionTime + sblockTimeStep*2, "cannot operate too soon");  // comment for debug
        onStock = true;
        optionPrice = _newOptionPrice;
        
        // reset
        lastOwner = currentOwner;
        lastSblockNo = 0;
        lastOprice = 0;
    }

    function setNewOptionPrice(uint newPrice) public ownerOnly {
        require(newPrice < optionPrice);
        require(block.timestamp > actionTime + sblockTimeStep, "cannot operate too soon");  // use small value for debug
        optionPrice = newPrice;
    }

    // three ways to end this contract:
    //   (whenNotExpired) the last owner pay DAI and withdraw ETH or
    //   (whenExpired) ethSeller take ETH back, or
    //                 if no one fillInEth() then originalOwner take back ETH
    function currentOwnerExercise() public ownerOnly whenCanExercise {
        require(block.timestamp > actionTime + sblockTimeStep, "cannot operate too soon");
        require(ERC20(currencyTokenAddr).allowance(msg.sender, address(this)) >= totalPriceInDai);
        onStock = false;
        exercised = true;

        iOptractRegistry(registryAddr).destructRecord();  // update record in "registry"
        ERC20(currencyTokenAddr).transferFrom(msg.sender, ethSeller, totalPriceInDai);
        selfdestruct(msg.sender);  // the residual send to msg.sender
    }

    function ethSellerWithdraw() public whenExpired {
        // if the contract owner don't exercise, ethSeller get the eth back
        require(msg.sender == ethSeller, "only ethSeller can call it");
        require(exercised == false, "already exercised");
        onStock = false;

        iOptractRegistry(registryAddr).destructRecord();  // update record in "registry"
        selfdestruct(msg.sender);  // the residual send to msg.sender
    }

    function cancelOptractCall() public ownerOnly whenExpired {
        // if no one fill in this contract, one can calcel this optract after expired (or anytime?)
        require(ethSeller == address(0));
        require(msg.sender == originalOwner);
        onStock == false;
        iOptractRegistry(registryAddr).destructRecord();  // update record in "registry"
        selfdestruct(msg.sender);  // the residual ETH send to msg.sender
    }

    // query functions
    function queryOptionPrice() public view returns (uint256) {
        return optionPrice;
    }

    function queryOrderPrice() public view returns (uint256) {
        return totalPriceInDai;
    }

    function queryOrderSize() public view returns (uint256) {
        return ethAmount;
    }

    function queryOnStock() public view returns (bool) {
        return onStock;
    }

    function isFilled() public view returns (bool) {
        return (ethSeller != address(0) && address(this).balance == ethAmount);
    }

}
