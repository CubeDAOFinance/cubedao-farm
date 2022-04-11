// SPDX-License-Identifier: MIT
pragma solidity 0.6.2;

import '../../capricorn-swap-lib/contracts/token/CRC20/ICRC20.sol';
import '../../capricorn-swap-lib/contracts/access/Ownable.sol';

import "./SmartChefInitializable.sol";

contract SmartChefFactory is Ownable {
    event NewSmartChefContract(address indexed smartChef);

	address [] public pools;

    constructor() public {
        //
    }

	function poolsLength() public view returns(uint length){
		return pools.length;
	}

    /*
     * @notice Deploy the pool
     * @param _stakedToken: staked token address
     * @param _rewardToken: reward token address
     * @param _rewardPerBlock: reward per block (in rewardToken)
     * @param _startBlock: start block
     * @param _endBlock: end block
     * @param _poolLimitPerUser: pool limit per user in stakedToken (if any, else 0)
     * @param _admin: admin address with ownership
     * @return address of new smart chef contract
     */
    function deployPool(
        ICRC20 _stakedToken,
        ICRC20 _rewardToken,
        uint256 _rewardPerBlock,
        uint256 _startBlock,
        uint256 _bonusEndBlock,
        uint256 _poolLimitPerUser,
        address _admin
    ) external onlyOwner {
        require(_stakedToken.totalSupply() >= 0);
        require(_rewardToken.totalSupply() >= 0);
        require(_stakedToken != _rewardToken, "Tokens must be be different");

        bytes memory bytecode = type(SmartChefInitializable).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(_stakedToken, _rewardToken, _startBlock));
        address smartChefAddress;

        assembly {
            smartChefAddress := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        SmartChefInitializable(smartChefAddress).initialize(
            _stakedToken,
            _rewardToken,
            _rewardPerBlock,
            _startBlock,
            _bonusEndBlock,
            _poolLimitPerUser,
            _admin
        );

		pools.push(smartChefAddress);

        emit NewSmartChefContract(smartChefAddress);
    }
}