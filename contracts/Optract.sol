pragma solidity ^0.5.2;
import "./SafeMath.sol";
// import "./RegistryInterface.sol";
// import "./BlockRegistryInterface.sol";

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
    uint256 public ethAmount;
    uint256 public totalPriceInDai;
    uint256 public optionPrice;
    uint256 public actionTime;  // right now, the actions are contract creation and newOwner()
    uint256 public period;  // length of time
    bool public onStock;
    bool public expired = false;  // query "registry" to determine when to expire
    bool public exercised = false;

    constructor (
        uint256 _ethAmount,
        uint256 _totalPriceInDai,
        address _registryAddr,
        address _originalOwner,
        address _blkAddr
    ) public {
        ethAmount = _ethAmount;
        totalPriceInDai = _totalPriceInDai;
        registryAddr = _registryAddr;
        originalOwner = _originalOwner;
        blkAddr = _blkAddr;

        onStock = true;  // for others to query
        currentOwner = _originalOwner;
        actionTime = block.timestamp;  // use this to avoid some too soon operations
        optionPrice = iRegistry(registryAddr).queryInitPrice();
    }

    modifier ownerOnly() {
        require(msg.sender = currentOwner, "not owner");
        _;
    }

    modifier ethFilled() {
        require (ethSeller != address(0) && address(this).balance > 0);
    }

    modifier isOnStock() {
        require(onStock == true, "not on stock");
        _;
    }

    modifier whenExpired() {
        require(iRegistry(registryAddr).isExpired(address(this)) == true, "can no longer excercise");
        _;
    }

    modifier whenNotExpired() {
        require(iRegistry(registryAddr).isExpired(address(this)) == false, "now can excercise");
        _;
    }

    // modifier whenLastExerciseChance() {
    //     uint256 expireTime = iRegistry(registryAddr).getExpireTime();
    //     require(block.timestamp >= expireTime - 8 hours && block.timestamp < expireTime);
    //     _;
    // }

    modifier whenBeforeLastExerciseChance() {
        uint256 expireTime = iRegistry(registryAddr).getExpireTime();
        require(block.timestamp < expireTime - 8 hours);
        _;
    }

    modifier whenCanExercise() {
        uint256 expireTime = iRegistry(registryAddr).getExpireTime();
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
        iDAI.transfer(address(this), msg.sender, optionPrice);
        // note: the originalOwner can hold for some time then withdraw or putOnStock() at some point
    }

    // a successful buyer can get the ownership (verified through state channel)
    function newOwner(
        bytes32[] memory proof,
        bool[] memory isLeft,
        bytes32 targetLeaf,
        bytes32 merkleRoot
    ) public ethFilled isOnStock whenBeforeLastExerciseChance returns(bool) {
        // verify:  require(calculateLeaf(msg.sender, some_more_data...) == targetLeaf))
        require(iBlockRegistry(blkAddr).merkleTreeValidator(proof, isLeft, targetLeaf, merkleRoot) == true, "invalid Merkle Proof");
        require(block.timestamp > actionTime + 2 hours, "cannot change ownership too soon");
        address prevOwner = currentOwner;

        // new owner
        onStock = false;  // has to call putOnStock() to make it on stock
        currentOwner = msg.sender;
        actionTime = block.timestamp;

        // the new owner transfer DAI to contract owner
        iDAI.transfer(currentOwner, prevOwner, optionPrice);
        iDAI.transfer(currentOwner, iBlockRegistry(blkAddr), optionPrice/500);  // 0.2% fee to block contract

        return true;
    }

    function putOnStock(uint256 _newOptionPrice) public ethFilled ownerOnly whenBeforeLastExerciseChance {
        // call it when a buyer want to sell the option
        require(onStock == false, "can only put on Stock once");
        onStock = true;
        optionPrice = _newOptionPrice;
    }

    // function setNewOptionPrice(uint newPrice) public ownerOnly {
    //     // any restrictions?
    //     optionPrice = newPrice;
    // }

    // two ways to end this contract:
    //   (whenNotExpired) the last owner pay DAI and withdraw ETH or (whenExpired) ethSeller take ETH back
    function currentOwnerExercise() public ownerOnly whenCanExercise {
        require(block.timestamp > actionTime + 2 hours, "");  // cannot withdraw right away
        onStock == false;
        exercised = true;
        iDAI.transfer(currentOwner, ethSeller, totalPriceInDai);
        msg.sender.transfer(address(this).balance);
        selfdestruct(msg.sender);
    }

    function ethSellerWithdraw() public whenExpired {
        // if the contract owner don't exercise, ethSeller get the eth back
        require(msg.sender == ethSeller, "only ethSeller can call it");
        require(exercised == false, "already exercised");
        onStock = false;
        msg.sender.transfer(address(this).balance);
        selfdestruct(msg.sender);
    }

    // query functions
    function queryOptionPrice() public returns (uint256) {
        return optionPrice;
    }

    function queryOrderPrice() public returns (uint256) {
        return totalPriceInDai;
    }

    function queryOrderSize() public returns (uint256) {
        return ethAmount;
    }

    function queryOnStock() public returns (bool) {
        return onStock;
    }

    function isFilled() public returns (bool) {
        return (ethSeller != address(0) && address(this).balance > 0);
    }

}
