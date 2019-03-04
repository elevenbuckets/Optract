pragma solidity ^0.5.2;


contract MemberShip {
    address public owner;
    address[3] public coreManager;
    uint public totalMembers = 0;
    uint public totalManagers = 0;
    uint public fee = 10000000000000000;
    uint public memberPeriod = 365 days;
    bool public paused = false;

    struct MemberInfo {
        address addr;
        uint since;  // beginning (unix) time of previous membership, unit: seconds
        uint penalty;  // the membership is valid until: since + memberPeriod - penalty;
        bytes32 kycid;  // know your customer id, leave it for future
        string notes;
    }

    mapping (uint => MemberInfo) internal memberDB;  // id to MemberInfo; id of managers start from 1, id of normal members start from 1000
    mapping (address => uint) internal addressToId;  // address to membership

    mapping (address => bool) public appWhitelist;

    constructor() public {
        owner = msg.sender;
        coreManager = [0xB440ea2780614b3c6a00e512f432785E7dfAFA3E,
                        0x4AD56641C569C91C64C28a904cda50AE5326Da41,
                        0xaF7400787c54422Be8B44154B1273661f1259CcD];
        // core managers are also members
        for (uint i=0; i<3; i++) {
            addManager(coreManager[i], i+1);
        }
    }

    modifier ownerOnly() {
        require(msg.sender == owner);
        _;
    }

    modifier coreManagerOnly() {
        require(msg.sender == coreManager[0] || msg.sender == coreManager[1] || msg.sender == coreManager[2]);
        _;
    }

    modifier managerOnly() {
        uint _id = addressToId[msg.sender];
        require(_id < 1000 && queryCoreManager());
        _;
    }

    modifier feePaid() {
        require(msg.value >= fee);  // or "=="?
        _;
    }

    modifier isMember() {
        uint _id = addressToId[msg.sender];
        require(memberDB[_id].addr == msg.sender && msg.sender != address(0));
        require(memberDB[_id].since > 0);
        // require(addressToId[msg.sender] == _id);
        _;
    }

    modifier isActiveMember() {
        uint _id = addressToId[msg.sender];
        require(memberDB[_id].addr == msg.sender && msg.sender != address(0));
        require(memberDB[_id].since + memberPeriod - memberDB[_id].penalty > block.timestamp || queryCoreManager());
        // require(_id != 0);  // already excluded by first condition
        _;
    }

    modifier whenNotPaused() {
        require(!paused);
        _;
    }

    modifier whenPaused {
        require(paused);
        _;
    }

    // membership
    function buyMembership() public payable feePaid returns (bool) {
        require(addressToId[msg.sender] == 0);
        totalMembers += 1;
        addressToId[msg.sender] = 1000 + totalMembers - totalManagers;
        memberDB[totalMembers] = MemberInfo(msg.sender, block.timestamp, 0, bytes32(1000 + totalMembers - totalManagers), "");
        return true;
    }

    // function cancelMembership() public isMember whenNotPaused returns (bool) {
    //     uint _id = addressToId[msg.sender];
    //     totalMembers -= 1;
    //     addressToId[msg.sender] = 0;
    //     memberDB[_id] = MemberInfo(address(0), 0, 0, bytes32(), "");
    //     return true;
    // }

    function renewMembership() public payable isMember feePaid whenNotPaused returns (uint) {
        // one can renew membership ? days before expire, and the new period start from this call
        uint _id = addressToId[msg.sender];
        require(block.timestamp > memberDB[_id].since + memberPeriod - 7 days);  // 7 days or?
        memberDB[_id].since = block.timestamp;
        return block.timestamp;
    }

    function addManager(address _addr, uint _id) public coreManagerOnly returns (bool) {
        require(memberDB[_id].addr == address(0));
        require(addressToId[_addr] == 0);  // is it necessary?
        require(_id < 1000);
        totalMembers += 1;
        totalManagers += 1;
        addressToId[_addr] = _id;
        memberDB[_id] = MemberInfo(_addr, block.timestamp, 0, bytes32(_id), "");
        return true;
    }

    function rmManager(address _addr, uint _id) public coreManagerOnly returns (bool) {
        require(memberDB[_id].addr != address(0));
        require(addressToId[_addr] != 0);
        require(_id < 1000);
        require(_addr != coreManager[0] && _addr != coreManager[1] && _addr != coreManager[2]);
        totalMembers -= 1;
        totalManagers -= 1;
        addressToId[_addr] = 0;
        memberDB[_id] = MemberInfo(address(0), 0, 0, bytes32(0), "");
        return true;
    }

    function assginKYCid(uint _id, bytes32 _kycid) external managerOnly returns (bool) {
        // instead of "managerOnly", probably add another group to do that
        require(memberDB[_id].since > 0 && memberDB[_id].addr != address(0));
        memberDB[_id].kycid = _kycid;
        return true;
    }

    function addWhitelistApps(address _addr) public coreManagerOnly returns (bool) {
        appWhitelist[_addr] = true;
        return true;
    }

    function rmWhitelistApps(address _addr) public coreManagerOnly returns (bool) {
        appWhitelist[_addr] = false;
        return true;
    }

    function addPenalty(uint _id, uint _penalty) external returns (uint) {
        require(appWhitelist[msg.sender] == true && msg.sender == address(0));  // the msg.sender (usually a contract) is in appWhitelist
        require(memberDB[_id].since > 0);  // is a member
        require(_penalty <= memberPeriod);  // prevent too much penalty

        if (memberDB[_id].penalty + _penalty > memberPeriod) {
            memberDB[_id].penalty = memberPeriod;  // if 0 then not a member
        } else {
            memberDB[_id].penalty += _penalty;
        }
        return memberDB[_id].penalty;
    }

    function readNotes(uint _id) external view returns (string memory) {
        require(addressToId[msg.sender] == _id || addressToId[msg.sender] < 1000);
        require(memberDB[_id].since > 0);
        return memberDB[_id].notes;
    }

    function addNotes(uint _id, string calldata _notes) external managerOnly {
        require(memberDB[_id].since > 0);
        memberDB[_id].notes = _notes;
    }

    // some query functions
    function addrIsMember(address _addr) public view returns (bool) {
        require(_addr != address(0));
        if (queryCoreManager()){
            return true;
        } else if (addressToId[_addr] != 0) {
            return true;
        } else {
            return false;
        }
    }

    function addrIsActiveMember(address _addr) public view returns (bool) {
        require(_addr != address(0));
        uint _id = addressToId[_addr];
        if (queryCoreManager()){
            return true;  // core managers
        } else if (memberDB[_id].since + memberPeriod - memberDB[_id].penalty > block.timestamp) {
            return true;  // not yet expire
        } else {
            return false;
        }
    }

    function idIsMember(uint _id) public view returns (bool) {
        // if (_id == 0) {
        //     return false;
        if (memberDB[_id].addr != address(0)) {
            return true;
        } else {
            return false;
        }
    }

    function idIsActiveMember(uint _id) public view returns (bool) {
        if (_id == 0) {
            return false;
        } else if (memberDB[_id].since + memberPeriod - memberDB[_id].penalty > block.timestamp || queryCoreManager()) {
            return true;
        } else {
            return false;
        }
    }

    function queryCoreManager() public view returns (bool) {
        if (msg.sender == coreManager[0] || msg.sender == coreManager[1] || msg.sender == coreManager[2]) {
            return true;
        } else {
            return false;
        }
    }

    function addrToId(address _addr) external view returns (uint) {
        return addressToId[_addr];
    }

    function getMemberInfo(address _addr) public view returns (uint, bytes32, uint, uint, bytes32){
        return getIdInfo(addressToId[_addr]);
    }

    function getIdInfo(uint _id) public view returns (uint, bytes32, uint, uint, bytes32){
        uint status;  // 0=failed connection, 1=active member, 2=expired, 3=not member
        if (_id == 0) {
            status = 3;
        } else {
            if (idIsActiveMember(_id)){
                status = 1;
            } else {
                status = 2;
            }
        }
        return (status, bytes32(_id), memberDB[_id].since, memberDB[_id].penalty, memberDB[_id].kycid);
    }

    // upgradable
    function pause() external coreManagerOnly whenNotPaused {
        paused = true;
    }

    function unpause() public ownerOnly whenPaused {
        // set to ownerOnly in case accounts of other managers are compromised
        paused = false;
    }


}
