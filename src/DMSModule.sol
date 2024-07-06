// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { AxiomV2Client } from "@axiom-crypto/v2-periphery/client/AxiomV2Client.sol";
import { EnumerableSet } from "./external/oz/EnumerableSet.sol";
import { Ownable } from "./external/oz/Ownable.sol";
import { ISafe, SafeUtils } from "./external/SafeUtils.sol";

/// @title Deadman Safe (DMS).
/// @dev Deadman Switch for safes that can be triggered if a safe has being dormant
///      for a specified period of time. If the switch is triggered, the safe's signers
///      and threshold will be updated.
contract DMSModule is Ownable, AxiomV2Client {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @dev The unique identifier of the circuit accepted by this contract.
    bytes32 immutable QUERY_SCHEMA;

    /// @dev The chain ID of the chain whose data the callback is expected to be called from.
    uint64 immutable SOURCE_CHAIN_ID;

    /// @dev The domain separator for the safe contract.
    bytes32 immutable DOMAIN_SEPARATOR;

    /// @dev Safe Address.
    address immutable SAFE_ADDRESS;

    /// @dev The minimum amount of time safe has to be dormant for before switch can be activated.
    uint64 private dormancyPeriod;

    /// @dev Whether the safe's switch has been activated.
    bool private switchActivated;

    /// @dev Safe signer threshold.
    uint256 private threshold;

    /// @dev The signers to add when switch is activated.
    EnumerableSet.AddressSet private contingentSigners;

    struct AxiomDataStruct {
        address safeAddress;
        address to;
        uint256 value;
        bytes data;
        uint8 operation;
        uint256 safeTxGas;
        uint256 baseGas;
        uint256 gasPrice;
        address gasToken;
        address refundReceiver;
        uint256 nonce;
        uint64 blockTimestamp;
        bytes32 txHash;
    }

    /// @notice Emitted when dm switch is activated.
    /// @param signers The Signers that were added when the switch was activated.
    event DeadmanSwitchActivated(address[] signers);
    
    /// @notice Emitted when more Signers are added.
    /// @param signers The Signers that were added.
    event ContingentSignersAdded(address[] signers);

    /// @notice Emitted when Signers are removed.
    /// @param signers The Signers that were removed.
    event ContingentSignersRemoved(address[] signers);

    /// @notice Emitted when threshold is updated.
    /// @param newThreshold The new threshold.
    event ThresholdUpdated(uint256 newThreshold);

    /// @notice Emitted when dormancy period is updated.
    /// @param period The new dormancy period.
    event DormancyPeriodUpdated(uint256 period);

    /// @param _axiomV2QueryAddress The address of the AxiomV2Query contract.
    /// @param _callbackSourceChainId The ID of the chain the query reads from.
    /// @param _querySchema The unique identifier of the circuit
    /// @param _safeAddress The safe address to setup switch for.
    /// @param _dormancyPeriod The initial dormancy period.
    /// @param _contingentSigners The initial contingent signers.
    /// @param _threshold The initial threshold.
    constructor(
        address _axiomV2QueryAddress, 
        uint64 _callbackSourceChainId, 
        bytes32 _querySchema,
        address _safeAddress,
        uint64 _dormancyPeriod,
        address[] memory _contingentSigners,
        uint256 _threshold
    ) AxiomV2Client(_axiomV2QueryAddress) Ownable(msg.sender) {
        QUERY_SCHEMA = _querySchema;
        SOURCE_CHAIN_ID = _callbackSourceChainId;
        SAFE_ADDRESS = _safeAddress;
        DOMAIN_SEPARATOR = ISafe(_safeAddress).domainSeparator();
        dormancyPeriod = _dormancyPeriod;
        threshold = _threshold;
        for(uint256 i = 0; i < _contingentSigners.length; i++){
            contingentSigners.add(_contingentSigners[i]);
        }
        emit ContingentSignersAdded(_contingentSigners);
    }

    /// @notice Add more contigency signers.
    /// @param newSigners The new Signers to be added.
    function addContingencySigners(
        address[] memory newSigners
    ) external onlyOwner() {
        for(uint256 i = 0; i < newSigners.length; i++){
            contingentSigners.add(newSigners[i]);
        }
        emit ContingentSignersAdded(newSigners);
    }

    /// @notice Remove contigency signers.
    /// @param signers The Signers to be removed.
    function removeContigencySigners(
        address[] memory signers
    ) external onlyOwner() {
        for(uint256 i = 0; i < signers.length; i++){
            contingentSigners.remove(signers[i]);
        }
        emit ContingentSignersRemoved(signers);
    }

    /// @notice Update threshold.
    /// @param _threshold The new threshold.
    function resetThreshold(uint256 _threshold) external onlyOwner() {
        assembly {
            if iszero(_threshold) {
                mstore(0x0, 0x53616665205468726573686f6c642043616e6e6f74204265205a65726f000000)
                revert(0x0, 0x1d)
            }
        }
        threshold = _threshold;
        emit ThresholdUpdated(_threshold);
    }

    /// @notice Update dormancy period.
    /// @param _period The new dormany period.
    function resetDormancyPeriod(uint64 _period) external onlyOwner() {
        dormancyPeriod = _period;
        emit DormancyPeriodUpdated(_period);
    }

    /// @return Safe nonce.
    function getSafeNonce() internal view returns(uint256) {
        return ISafe(SAFE_ADDRESS).nonce();
    }

    /// @dev Handles Axiom callback results, Execute switch.
    function _handleCallback(AxiomDataStruct memory axiomDataStruct) internal {
        bytes32 _txHash = SafeUtils.getTransactionHash(
            axiomDataStruct.to,
            axiomDataStruct.value,
            axiomDataStruct.data,
            axiomDataStruct.operation,
            axiomDataStruct.safeTxGas,
            axiomDataStruct.baseGas,
            axiomDataStruct.gasPrice,
            axiomDataStruct.gasToken,
            axiomDataStruct.refundReceiver,
            axiomDataStruct.nonce,
            DOMAIN_SEPARATOR
        );
        
        // Ensure that safe address from axiom callback is valid.
        if(SAFE_ADDRESS != axiomDataStruct.safeAddress){
            assembly {
                mstore(0x0, 0x57726f6e67205361666520546172676574000000000000000000000000000000)
                revert(0x0, 0x11)
            }
        }

        // Ensure that data tx hash from axiom callback is valid.
        if(axiomDataStruct.txHash != _txHash){
            assembly {
                mstore(0x0, 0x54782044617461204861736820446f6573204e6f74204d617463680000000000)
                revert(0x0, 0x1b) 
            }
        }

        // Ensure that data from axiom callback is from safe's lastest tx.
        if(getSafeNonce() != (axiomDataStruct.nonce + 1)){
            assembly {
                mstore(0x0, 0x53616665204e6f6e63652056616c756520496e76616c69640000000000000000)
                revert(0x0, 0x18) 
            }
        }

        // Ensure that at least `dormancyPeriod` has passed since safe's last tx.
        if(block.timestamp < (dormancyPeriod  + axiomDataStruct.blockTimestamp)){
            assembly {
                mstore(0x0, 0x53616665204e6f7420446f726d616e7400000000000000000000000000000000)
                revert(0x0, 0x10) 
            }
        }

        uint256 signerLen = contingentSigners.length();
        uint256 _threshold = threshold;
        for(uint256 i = 0; i < signerLen; i++){
            bytes memory data = abi.encodePacked(
                bytes4(0x0d582f13),
                bytes32(uint256(uint160(contingentSigners.at(i)))),
                bytes32(_threshold)
            );
            // Add signer to safe.
            if(!ISafe(SAFE_ADDRESS).execTransactionFromModule(SAFE_ADDRESS, 0, data, 0)){
                assembly {
                    mstore(0x0, 0x53616665205478204661696c6564000000000000000000000000000000000000)
                    revert(0x0, 0x0e) 
                }
            }
        }

        switchActivated = true;
        emit DeadmanSwitchActivated(contingentSigners.values());
    }

    /// @inheritdoc AxiomV2Client
    function _validateAxiomV2Call(
        AxiomCallbackType, // callbackType,
        uint64 sourceChainId,
        address, // caller,
        bytes32 querySchema,
        uint256, // queryId,
        bytes calldata // extraData
    ) internal view override {
        // Add your validation logic here for checking the callback responses
        if(sourceChainId != SOURCE_CHAIN_ID){
            assembly {
                mstore(0x0, 0x536f7572636520636861696e20494420646f6573206e6f74206d617463680000)
                revert(0x0, 0x1e)
            }
        }
        if(querySchema != QUERY_SCHEMA){
            assembly {
                mstore(0x0, 0x496e76616c696420717565727920736368656d61000000000000000000000000)
                revert(0x0, 0x14)
            }
        }
    }

    /// @inheritdoc AxiomV2Client
    function _axiomV2Callback(
        uint64, // sourceChainId,
        address, // caller,
        bytes32, // querySchema,
        uint256, // queryId,
        bytes32[] calldata axiomResults,
        bytes calldata // extraData
    ) internal override {
        if(switchActivated){
            assembly {
                mstore(0x0, 0x53776974636820616c7265616479206163746976617465640000000000000000)
                revert(0x0, 0x18)
            }
        }
        // The callback from the Axiom ZK circuit proof comes out here and we can handle the results from the
        // `axiomResults` array.
        AxiomDataStruct memory axiomDataStruct;
        axiomDataStruct.safeAddress = address(uint160(uint256(axiomResults[0])));
        axiomDataStruct.to = address(uint160(uint256(axiomResults[1])));
        axiomDataStruct.value = uint256(axiomResults[2]);
        axiomDataStruct.operation = uint8(uint256(axiomResults[3]));
        axiomDataStruct.safeTxGas = uint256(axiomResults[4]);
        axiomDataStruct.baseGas = uint256(axiomResults[5]);
        axiomDataStruct.gasPrice = uint256(axiomResults[6]);
        axiomDataStruct.gasToken = address(uint160(uint256(axiomResults[7])));
        axiomDataStruct.refundReceiver = address(uint160(uint256(axiomResults[8])));
        axiomDataStruct.nonce = uint256(axiomResults[9]);
        axiomDataStruct.blockTimestamp = uint64(uint256(axiomResults[10]));
        axiomDataStruct.txHash = axiomResults[11];
        axiomDataStruct.data = abi.encodePacked(bytes4(axiomResults[12] << 224));
        
        uint256 dataLen = axiomResults.length - 13;

        for(uint256 i; i < dataLen; i++){
            axiomDataStruct.data = abi.encodePacked(
                axiomDataStruct.data, 
                axiomResults[i + 13]
            );
        }

        _handleCallback(axiomDataStruct);
    }
}