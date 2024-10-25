// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {IHats} from "../interfaces/hats/IHats.sol";

contract MockHats is IHats {
    uint256 public count = 0;
    mapping(uint256 => address) hatWearers;

    function mintTopHat(
        address _target,
        string memory,
        string memory
    ) external returns (uint256 topHatId) {
        topHatId = count;
        count++;
        hatWearers[topHatId] = _target;
    }

    function createHat(
        uint256,
        string calldata,
        uint32,
        address,
        address,
        bool,
        string calldata
    ) external returns (uint256 newHatId) {
        newHatId = count;
        count++;
    }

    function mintHat(
        uint256 hatId,
        address wearer
    ) external returns (bool success) {
        success = true;
        hatWearers[hatId] = wearer;
    }

    function transferHat(uint256 _hatId, address _from, address _to) external {
        require(
            hatWearers[_hatId] == _from,
            "MockHats: Invalid current wearer"
        );
        hatWearers[_hatId] = _to;
    }

    function isWearerOfHat(
        address _user,
        uint256 _hatId
    ) external view returns (bool isWearer) {
        isWearer = hatWearers[_hatId] == _user;
    }
}
