// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IRandomTool {

    /*** User Interface ***/
    function getRandoms(address nftAddr, uint256 rangeMaximum) external returns (uint256);
}