// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultisingWallet {

    event ExecutionSuccess(bytes32 txHash);    // 交易成功事件
    event ExecutionFailure(bytes32 txHash);    // 交易失败事件

    address[] public owners;                   // 多签持有人数组 
    mapping(address => bool) public isOwner;   // 记录一个地址是否为多签
    uint256 public ownerCount;                 // 多签持有人数量
    uint256 public threshold;                  // 多签执行门槛，交易至少有n个多签人签名才能被执行。
    uint256 public nonce;                      // nonce，防止签名重放攻击
    uint256 public numConfirmations;
    mapping (address => mapping (bytes32 => bool)) public isConfirm;
    bytes32 public txHash;

    constructor(        
        address[] memory _owners,
        uint256 _threshold
    ) {
        _setupOwners(_owners, _threshold);
    }

    function _setupOwners(address[] memory _owners, uint256 _threshold) internal {
        // threshold没被初始化过
        require(threshold == 0, "WTF5000");
        // 多签执行门槛 小于 多签人数
        require(_threshold <= _owners.length, "WTF5001");
        // 多签执行门槛至少为1
        require(_threshold >= 1, "WTF5002");

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            // 多签人不能为0地址，本合约地址，不能重复
            require(owner != address(0) && owner != address(this) && !isOwner[owner], "WTF5003");
            owners.push(owner);
            isOwner[owner] = true;
        }
        ownerCount = _owners.length;
        threshold = _threshold;
    }


    function encodeTransactionData(
        address to,
        uint256 value,
        bytes memory data,
        uint256 transactionNonce,
        uint256 chainId
    ) public pure returns (bytes32) {
    return keccak256(abi.encodePacked(to, value, data, transactionNonce, chainId));
}

    function execTransaction(
        address to,
        uint256 value,
        bytes memory data
    ) public payable virtual returns (bool success) {
        // 编码交易数据，计算哈希
        txHash = encodeTransactionData(to, value, data, nonce, block.chainid);
        nonce++;  // 增加nonce
        if(numConfirmations >= threshold){
            // 利用call执行交易，并获取交易结果
            (success, ) = to.call{value: value}(data);
            require(success , "WTF5004");
            if (success) emit ExecutionSuccess(txHash);
            else emit ExecutionFailure(txHash);
        }else{
            revert("numConfirmations insufficient");
        }
    }

    function confirm() public {
        require(isOwner[msg.sender] == true, "No Permission");
        require(isConfirm[msg.sender][txHash] == false,"have confirmd");
        numConfirmations++;
        isConfirm[msg.sender][txHash] == true;
    }
}