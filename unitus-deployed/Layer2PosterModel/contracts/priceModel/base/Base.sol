// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "../../library/Initializable.sol";
import "../../library/Ownable.sol";

abstract contract Base is Initializable, Ownable {
    constructor() public {
        initialize();
    }

    /**
     * @notice Do not pay into Base.
     */
    receive() external payable {
        revert();
    }

    /**
     * @dev Initialize contract to set some configs.
     */
    function initialize() public virtual initializer {
        __Ownable_init();
    }
}
