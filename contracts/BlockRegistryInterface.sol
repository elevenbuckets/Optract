pragma solidity ^0.5.2;

interface iBlockRegistry {

    // function submitMerkleRoot(uint _initHeight, bytes32 _merkleRoot, string calldata _ipfsAddr) external returns (bool);
    function getSblockNo() external view returns (uint);
    function getBlockInfo(uint _sblockNo) external view returns (uint, bytes32, string memory);
}
