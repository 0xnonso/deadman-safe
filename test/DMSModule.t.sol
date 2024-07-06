// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@axiom-crypto/axiom-std/AxiomTest.sol";
import { DMSModule } from "../src/DMSModule.sol";
import { ISafe } from "../src/external/SafeUtils.sol";

contract DMSModuleTest is AxiomTest {
    using Axiom for Query;

    struct AxiomInput {
        uint64 blockNumber;
        uint256 txIdx;
        uint256 logIdx;
        address safeAddress;
        address to;
        uint256 value;
        uint256[] data;
        uint8 operation;
        uint256 safeTxGas;
        uint256 baseGas;
        uint256 gasPrice;
        address gasToken;
        address refundReceiver;
        uint256 nonce;
    }

    DMSModule public dms;
    AxiomInput public input;
    bytes32 public querySchema;
    address[] public signers;
    uint256 threshold;

    function setUp() public {
        _createSelectForkAndSetupAxiom("provider");

        uint256[] memory inputData = new uint256[](16);
        inputData[0] = 0x8d80ff0a;
        inputData[1] = 0x0000000000000000000000000000000000000000000000000000000000000020;
        inputData[2] = 0x0000000000000000000000000000000000000000000000000000000000000187;
        inputData[3] = 0x00dac17f958d2ee523a2206206994597c13d831ec70000000000000000000000;
        inputData[4] = 0x0000000000000000000000000000000000000000000000000000000000000000;
        inputData[5] = 0x000000000000000000000000000000000000000044a9059cbb00000000000000;
        inputData[6] = 0x00000000007566b8c9f2d17804ef21a9a8cca14d0de271e7bb00000000000000;
        inputData[7] = 0x000000000000000000000000000000000000000033d00c5040000000000000ca;
        inputData[8] = 0x73a6df4c58b84c5b4b847fe8ff39000000000000000000000000000000000000;
        inputData[9] = 0x0000000000000000000000000000000000000000000000000000000000000000;
        inputData[10] = 0x0000000000000000000000000044a9059cbb0000000000000000000000007566;
        inputData[11] = 0xb8c9f2d17804ef21a9a8cca14d0de271e7bb0000000000000000000000000000;
        inputData[12] = 0x00000000000000000000bb59a27953c60000007566b8c9f2d17804ef21a9a8cc;
        inputData[13] = 0xa14d0de271e7bb00000000000000000000000000000000000000000000000004;
        inputData[14] = 0x29d069189e000000000000000000000000000000000000000000000000000000;
        inputData[15] = 0x0000000000000000000000000000000000000000000000000000000000000000;

        input =
            AxiomInput(
                {
                    blockNumber: 19590789,
                    txIdx: 47,
                    logIdx: 15,
                    safeAddress: 0xdae8f99814CC3Aa541909cE07E59d0C208FEdbb7,
                    to: 0x40A2aCCbd92BCA938b02010E17A5b8929b49130D,
                    value: 0,
                    data: inputData,
                    operation: 1,
                    safeTxGas: 0,
                    baseGas: 0,
                    gasPrice: 0,
                    gasToken: 0x0000000000000000000000000000000000000000,
                    refundReceiver: 0x0000000000000000000000000000000000000000,
                    nonce: 5
                }
            );
        querySchema = axiomVm.readCircuit("app/axiom/dms.circuit.ts");

        signers.push(address(0xB0b));
        threshold = 1;

        dms = new DMSModule(
            axiomV2QueryAddress, 
            uint64(block.chainid), 
            querySchema,
            input.safeAddress,
            50 days,
            signers,
            threshold
        );

        // Enable safe module.
        vm.store(
            input.safeAddress, 
            keccak256(abi.encode(address(dms), 1)), 
            bytes32(uint256(0x01))
        );
    }

    function testAxiomResult() public {
        // create a query into Axiom with default parameters
        Query memory q = query(querySchema, abi.encode(input), address(dms));

        // send the query to Axiom
        q.send();

        // prank fulfillment of the query, returning the Axiom results 
        bytes32[] memory results = q.prankFulfill();

        assertEq(input.safeAddress, address(uint160(uint256(results[0]))));
        assertEq(input.to, address(uint160(uint256(results[1]))));
        assertEq(input.value, uint256(results[2]));
        assertEq(input.operation, uint8(uint256(results[3])));
        assertEq(input.safeTxGas, uint256(results[4]));
        assertEq(input.baseGas, uint256(results[5]));
        assertEq(input.gasPrice, uint256(results[6]));
        assertEq(input.gasToken, address(uint160(uint256(results[7]))));
        assertEq(input.refundReceiver, address(uint160(uint256(results[8]))));
        assertEq(input.nonce, uint256(results[9]));
    }

    function testSafeSignersAndThresholdUpdated() public {
        // create a query into Axiom with default parameters
        Query memory q = query(querySchema, abi.encode(input), address(dms));

        // send the query to Axiom
        q.send();

        q.prankFulfill();

        ISafe _safe = ISafe(input.safeAddress);
        for(uint256 i = 0; i < signers.length; i++){
            assert(_safe.isOwner(signers[i]));
        }
        assertEq(_safe.getThreshold(), threshold);   
    }

    function testInvalidAxiomInput() public {
        AxiomInput memory _input = input;
        _input.to = address(0x0);
        // create a query into Axiom with default parameters
        Query memory q = query(querySchema, abi.encode(_input), address(dms));

        // send the query to Axiom
        q.send();

        vm.expectRevert(bytes("Tx Data Hash Does Not Match"));

        q.prankFulfill();

        _input = input;
        _input.nonce = 4;
        // create a query into Axiom with default parameters
        q = query(querySchema, abi.encode(_input), address(dms));

        // send the query to Axiom
        q.send();

        vm.expectRevert(bytes("Tx Data Hash Does Not Match"));

        q.prankFulfill();

        _input = input;
        _input.value = 1;
        // create a query into Axiom with default parameters
        q = query(querySchema, abi.encode(_input), address(dms));

        // send the query to Axiom
        q.send();

        vm.expectRevert(bytes("Tx Data Hash Does Not Match"));

        q.prankFulfill();

        _input = input;
        _input.operation = 0;
        // create a query into Axiom with default parameters
        q = query(querySchema, abi.encode(_input), address(dms));

        // send the query to Axiom
        q.send();

        vm.expectRevert(bytes("Tx Data Hash Does Not Match"));

        q.prankFulfill();

        _input = input;
        _input.safeTxGas = 1;
        // create a query into Axiom with default parameters
        q = query(querySchema, abi.encode(_input), address(dms));

        // send the query to Axiom
        q.send();

        vm.expectRevert(bytes("Tx Data Hash Does Not Match"));

        q.prankFulfill();

        _input = input;
        _input.baseGas = 1;
        // create a query into Axiom with default parameters
        q = query(querySchema, abi.encode(_input), address(dms));

        // send the query to Axiom
        q.send();

        vm.expectRevert(bytes("Tx Data Hash Does Not Match"));

        q.prankFulfill();

        _input = input;
        _input.gasPrice = 1;
        // create a query into Axiom with default parameters
        q = query(querySchema, abi.encode(_input), address(dms));

        // send the query to Axiom
        q.send();

        vm.expectRevert(bytes("Tx Data Hash Does Not Match"));

        q.prankFulfill();

        _input = input;
        _input.gasToken = address(0x02);
        // create a query into Axiom with default parameters
        q = query(querySchema, abi.encode(_input), address(dms));

        // send the query to Axiom
        q.send();

        vm.expectRevert(bytes("Tx Data Hash Does Not Match"));

        q.prankFulfill();

        _input = input;
        _input.refundReceiver = address(0x02);
        // create a query into Axiom with default parameters
        q = query(querySchema, abi.encode(_input), address(dms));

        // send the query to Axiom
        q.send();

        vm.expectRevert(bytes("Tx Data Hash Does Not Match"));

        q.prankFulfill();
    }

    function testSafeNotDormant() public {
        dms.resetDormancyPeriod(100 days);

        // create a query into Axiom with default parameters
        Query memory q = query(querySchema, abi.encode(input), address(dms));

        // send the query to Axiom
        q.send();

        vm.expectRevert(bytes("Safe Not Dormant"));
        // prank fulfillment of the query
        q.prankFulfill();
    }

    function testThresholdCannotBeZero() public {
        vm.expectRevert(bytes("Safe Threshold Cannot Be Zero"));
        dms.resetThreshold(0);
    }

    function testSwitchActivated() public {
        // create a query into Axiom with default parameters
        Query memory q = query(querySchema, abi.encode(input), address(dms));

        // send the query to Axiom
        q.send();

        // prank fulfillment of the query
        q.prankFulfill();

        q.send();

        vm.expectRevert(bytes("Switch already activated"));
        q.prankFulfill();
    }
}
