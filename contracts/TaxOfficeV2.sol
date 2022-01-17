// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./owner/Operator.sol";
import "./interfaces/ITaxable.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IERC20.sol";

/*
    ____        __           _         _______
   / __ \____  / /___ ______(_)____   / ____(_)___  ____ _____  ________
  / /_/ / __ \/ / __ `/ ___/ / ___/  / /_  / / __ \/ __ `/ __ \/ ___/ _ \
 / ____/ /_/ / / /_/ / /  / (__  )  / __/ / / / / / /_/ / / / / /__/  __/
/_/    \____/_/\__,_/_/  /_/____/  /_/   /_/_/ /_/\__,_/_/ /_/\___/\___/

    https://polarisfinance.io
*/
contract TaxOfficeV2 is Operator {
    using SafeMath for uint256;

    address public polar = address(0x6c021Ae822BEa943b2E66552bDe1D2696a53fbB7);
    address public wftm = address(0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83);
    address public uniRouter = address(0xF491e7B69E4244ad4002BC14e878a34207E38c29);

    mapping(address => bool) public taxExclusionEnabled;

    function setTaxTiersTwap(uint8 _index, uint256 _value) public onlyOperator returns (bool) {
        return ITaxable(polar).setTaxTiersTwap(_index, _value);
    }

    function setTaxTiersRate(uint8 _index, uint256 _value) public onlyOperator returns (bool) {
        return ITaxable(polar).setTaxTiersRate(_index, _value);
    }

    function enableAutoCalculateTax() public onlyOperator {
        ITaxable(polar).enableAutoCalculateTax();
    }

    function disableAutoCalculateTax() public onlyOperator {
        ITaxable(polar).disableAutoCalculateTax();
    }

    function setTaxRate(uint256 _taxRate) public onlyOperator {
        ITaxable(polar).setTaxRate(_taxRate);
    }

    function setBurnThreshold(uint256 _burnThreshold) public onlyOperator {
        ITaxable(polar).setBurnThreshold(_burnThreshold);
    }

    function setTaxCollectorAddress(address _taxCollectorAddress) public onlyOperator {
        ITaxable(polar).setTaxCollectorAddress(_taxCollectorAddress);
    }

    function excludeAddressFromTax(address _address) external onlyOperator returns (bool) {
        return _excludeAddressFromTax(_address);
    }

    function _excludeAddressFromTax(address _address) private returns (bool) {
        if (!ITaxable(polar).isAddressExcluded(_address)) {
            return ITaxable(polar).excludeAddress(_address);
        }
    }

    function includeAddressInTax(address _address) external onlyOperator returns (bool) {
        return _includeAddressInTax(_address);
    }

    function _includeAddressInTax(address _address) private returns (bool) {
        if (ITaxable(polar).isAddressExcluded(_address)) {
            return ITaxable(polar).includeAddress(_address);
        }
    }

    function taxRate() external view returns (uint256) {
        return ITaxable(polar).taxRate();
    }

    function addLiquidityTaxFree(
        address token,
        uint256 amtPolar,
        uint256 amtToken,
        uint256 amtPolarMin,
        uint256 amtTokenMin
    )
        external
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        require(amtPolar != 0 && amtToken != 0, "amounts can't be 0");
        _excludeAddressFromTax(msg.sender);

        IERC20(polar).transferFrom(msg.sender, address(this), amtPolar);
        IERC20(token).transferFrom(msg.sender, address(this), amtToken);
        _approveTokenIfNeeded(polar, uniRouter);
        _approveTokenIfNeeded(token, uniRouter);

        _includeAddressInTax(msg.sender);

        uint256 resultAmtPolar;
        uint256 resultAmtToken;
        uint256 liquidity;
        (resultAmtPolar, resultAmtToken, liquidity) = IUniswapV2Router(uniRouter).addLiquidity(
            polar,
            token,
            amtPolar,
            amtToken,
            amtPolarMin,
            amtTokenMin,
            msg.sender,
            block.timestamp
        );

        if(amtPolar.sub(resultAmtPolar) > 0) {
            IERC20(polar).transfer(msg.sender, amtPolar.sub(resultAmtPolar));
        }
        if(amtToken.sub(resultAmtToken) > 0) {
            IERC20(token).transfer(msg.sender, amtToken.sub(resultAmtToken));
        }
        return (resultAmtPolar, resultAmtToken, liquidity);
    }

    function addLiquidityETHTaxFree(
        uint256 amtPolar,
        uint256 amtPolarMin,
        uint256 amtFtmMin
    )
        external
        payable
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        require(amtPolar != 0 && msg.value != 0, "amounts can't be 0");
        _excludeAddressFromTax(msg.sender);

        IERC20(polar).transferFrom(msg.sender, address(this), amtPolar);
        _approveTokenIfNeeded(polar, uniRouter);

        _includeAddressInTax(msg.sender);

        uint256 resultAmtPolar;
        uint256 resultAmtFtm;
        uint256 liquidity;
        (resultAmtPolar, resultAmtFtm, liquidity) = IUniswapV2Router(uniRouter).addLiquidityETH{value: msg.value}(
            polar,
            amtPolar,
            amtPolarMin,
            amtFtmMin,
            msg.sender,
            block.timestamp
        );

        if(amtPolar.sub(resultAmtPolar) > 0) {
            IERC20(polar).transfer(msg.sender, amtPolar.sub(resultAmtPolar));
        }
        return (resultAmtPolar, resultAmtFtm, liquidity);
    }

    function setTaxablePolarOracle(address _polarOracle) external onlyOperator {
        ITaxable(polar).setPolarOracle(_polarOracle);
    }

    function transferTaxOffice(address _newTaxOffice) external onlyOperator {
        ITaxable(polar).setTaxOffice(_newTaxOffice);
    }

    function taxFreeTransferFrom(
        address _sender,
        address _recipient,
        uint256 _amt
    ) external {
        require(taxExclusionEnabled[msg.sender], "Address not approved for tax free transfers");
        _excludeAddressFromTax(_sender);
        IERC20(polar).transferFrom(_sender, _recipient, _amt);
        _includeAddressInTax(_sender);
    }

    function setTaxExclusionForAddress(address _address, bool _excluded) external onlyOperator {
        taxExclusionEnabled[_address] = _excluded;
    }

    function _approveTokenIfNeeded(address _token, address _router) private {
        if (IERC20(_token).allowance(address(this), _router) == 0) {
            IERC20(_token).approve(_router, type(uint256).max);
        }
    }
}
