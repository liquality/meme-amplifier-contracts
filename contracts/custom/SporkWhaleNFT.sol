// ERC1155
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC1155Burnable} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract SporkWhaleNFT is ERC1155, Pausable, Ownable, ERC1155Burnable  {
    using Strings for uint256;
    address public operator;
    string public contractURI;

    error SporkWhaleNFT__OnlyOperator(address sender);
    
    // solhint-disable-next-line
    constructor(address _operator, string memory _uri) ERC1155(_uri) Ownable(msg.sender) {
        operator = _operator;
    }

    function setContractURI(string  memory _contractURI) public onlyOwner {
        contractURI = _contractURI;
    }

    function setURI(string memory newURI) public onlyOwner {
        _setURI(newURI);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address account, uint256 id, uint256 amount, bytes memory data) public {
        _requireFromAuthorizedOperator();
        _mint(account, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public {
        _requireFromAuthorizedOperator();
        _mintBatch(to, ids, amounts, data);
    }

    function uri(uint256 _id) public view override returns (string memory) {
        return string(abi.encodePacked(super.uri(_id), _id.toString(), ".json"));
    }

    function _requireFromAuthorizedOperator() internal view  {
        if (operator != msg.sender) {
            revert SporkWhaleNFT__OnlyOperator(msg.sender);
        }
    }
}