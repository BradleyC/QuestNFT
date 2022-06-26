// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

interface IAbstractTask {

    function evaluate(bytes32[] taskData) external returns (bool);

}