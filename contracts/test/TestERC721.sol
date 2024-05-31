//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TestERC721 is ERC721 {
    string private __baseUri;

    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseUri_
    ) ERC721(name_, symbol_) {
        __baseUri = baseUri_;
    }

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    function setBaseURI(string memory baseUri_) external {
        __baseUri = baseUri_;
    }

    function _baseURI() internal view override returns (string memory) {
        return __baseUri;
    }
}
