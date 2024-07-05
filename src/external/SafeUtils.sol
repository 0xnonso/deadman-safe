// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ISafe {
    /// @dev Allows a Module to execute a Safe transaction without any further confirmations.
    /// @param to Destination address of module transaction.
    /// @param value Ether value of module transaction.
    /// @param data Data payload of module transaction.
    /// @param operation Operation type of module transaction.
    function execTransactionFromModule(
        address to,
        uint256 value,
        bytes memory data,
        uint8 operation
    ) external returns (bool success);

    /// @dev Returns if an module is enabled
    /// @return True if the module is enabled
    function isModuleEnabled(address module) external view returns (bool);

    function domainSeparator() external view returns (bytes32);

    function nonce() external view returns (uint256);

    function isOwner(address) external view returns (bool);

    function getThreshold() external view returns (uint256);
}

library SafeUtils {
    /**
     * @notice Returns the pre-image of the transaction hash (see getTransactionHash).
     * @param to Destination address.
     * @param value Ether value.
     * @param data Data payload.
     * @param operation Operation type.
     * @param safeTxGas Gas that should be used for the safe transaction.
     * @param baseGas Gas costs for that are independent of the transaction execution(e.g. base transaction fee, signature check, payment of the refund)
     * @param gasPrice Maximum gas price that should be used for this transaction.
     * @param gasToken Token address (or 0 if ETH) that is used for the payment.
     * @param refundReceiver Address of receiver of gas payment (or 0 if tx.origin).
     * @param _nonce Transaction nonce.
     * @return Transaction hash bytes.
     */
    function encodeTransactionData(
        address to,
        uint256 value,
        bytes memory data,
        uint8 operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver,
        uint256 _nonce,
        bytes32 domainSeparator
    ) private pure returns (bytes memory) {
        bytes32 safeTxHash = keccak256(
            abi.encode(
                bytes32(0xbb8310d486368db6bd6f849402fdd73ad53d316b5a4b2644ad6efe0f941286d8),
                to,
                value,
                keccak256(data),
                operation,
                safeTxGas,
                baseGas,
                gasPrice,
                gasToken,
                refundReceiver,
                _nonce
            )
        );
        return abi.encodePacked(bytes1(0x19), bytes1(0x01), domainSeparator, safeTxHash);
    }

    function getTransactionHash(
        address to,
        uint256 value,
        bytes memory data,
        uint8 operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver,
        uint256 _nonce,
        bytes32 domainSeparator
    ) internal pure returns (bytes32) {
        return keccak256(
            encodeTransactionData(
                to, 
                value, 
                data, 
                operation, 
                safeTxGas, 
                baseGas, 
                gasPrice, 
                gasToken, 
                refundReceiver, 
                _nonce,
                domainSeparator
            ));
    }
}