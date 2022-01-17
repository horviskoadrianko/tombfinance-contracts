// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/*
    ____        __           _         _______
   / __ \____  / /___ ______(_)____   / ____(_)___  ____ _____  ________
  / /_/ / __ \/ / __ `/ ___/ / ___/  / /_  / / __ \/ __ `/ __ \/ ___/ _ \
 / ____/ /_/ / / /_/ / /  / (__  )  / __/ / / / / / /_/ / / / / /__/  __/
/_/    \____/_/\__,_/_/  /_/____/  /_/   /_/_/ /_/\__,_/_/ /_/\___/\___/

    https://polarisfinance.io
*/
contract PolarTaxOracle is Ownable {
    using SafeMath for uint256;

    IERC20 public polar;
    IERC20 public wftm;
    address public pair;

    constructor(
        address _polar,
        address _wftm,
        address _pair
    ) public {
        require(_polar != address(0), "polar address cannot be 0");
        require(_wftm != address(0), "wftm address cannot be 0");
        require(_pair != address(0), "pair address cannot be 0");
        polar = IERC20(_polar);
        wftm = IERC20(_wftm);
        pair = _pair;
    }

    function consult(address _token, uint256 _amountIn) external view returns (uint144 amountOut) {
        require(_token == address(polar), "token needs to be polar");
        uint256 polarBalance = polar.balanceOf(pair);
        uint256 wftmBalance = wftm.balanceOf(pair);
        return uint144(polarBalance.div(wftmBalance));
    }

    function setPolar(address _polar) external onlyOwner {
        require(_polar != address(0), "polar address cannot be 0");
        polar = IERC20(_polar);
    }

    function setWftm(address _wftm) external onlyOwner {
        require(_wftm != address(0), "wftm address cannot be 0");
        wftm = IERC20(_wftm);
    }

    function setPair(address _pair) external onlyOwner {
        require(_pair != address(0), "pair address cannot be 0");
        pair = _pair;
    }



}
