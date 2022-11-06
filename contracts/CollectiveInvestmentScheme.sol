// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CollectiveInvestmentScheme is IERC20 {
    // using
    using SafeMath for uint;

    // enums
    enum State { Offering, Ordering, AssetHolding, AssetSelling, AssetSold, Closed }

    // external contracts
    ERC20 private _WETHcontract;

    // --- vvv fields vvv --- 
    // scheme info
    State private _state;
    uint private _offerClosingTime;
    uint private _orderExpiration;
    uint private _maturity;

    // underlying
    address private _underlyingAsset; // this must be hide in some manner...

    // deposit related.
    uint private _totalWETH;
    mapping(address => uint) private _depositWETH;
    address[] private _depositors;

    // as token
    mapping(address => mapping(address => uint)) private _allowance;

    // execution result
    uint private _purchasePrice;
    uint private _soldPrice;

    // --- ^^^ fields ^^^ --- 

    // modifiers
    modifier onlyOffering() {
        require(_state == State.Offering, "Available only when offering");
        _;
    }
    modifier beforeOfferClose() {
        require(block.timestamp < _offerClosingTime, "Offer period already ended");
        _;
    }
    modifier onlyOrdering() {
        require(_state == State.Ordering, "Available only when ordering");
        _;
    }
    modifier onlyAssetHolding() {
        require(_state == State.AssetHolding, "Available only when ordering");
        require(block.timestamp < _maturity, "This scheme reaches maturity.");
        _;
    }
    modifier onlyAssetSelling() {
        require(_state == State.AssetSelling, "Available only when asset selling.");
        _;
    }
    modifier onlyDepositor() {
        require(_depositWETH[msg.sender] != 0, "Only depositor can call.");
        _;
    }


    constructor(
        address WETHcontract_,
        address underlyingAsset_,
        uint offerClosingTime_,
        uint orderExpiration_,
        uint maturity_
    )
        // Ownable()
    {
        require(WETHcontract_ != address(0));
        require(underlyingAsset_ != address(0));
        require(block.timestamp <= offerClosingTime_, "Offer closing time must be in future.");
        require(offerClosingTime_ <= block.timestamp + 90 days , "Offer closing time is too future.");
        require(offerClosingTime_ <= orderExpiration_, "Order expiration must be after offer closing time.");
        require(orderExpiration_ <= offerClosingTime_ + 90 days, "Order expiration is too future of offer closing time.");
        require(offerClosingTime_ <= maturity_, "Maturity must be after offer closing time.");
        require(maturity_ <= offerClosingTime_ + 180 days, "Maturity is too future of offer closing time.");
        _WETHcontract = ERC20(WETHcontract_);
        _underlyingAsset = underlyingAsset_;
        _offerClosingTime = offerClosingTime_;
        _orderExpiration = orderExpiration_;
        _maturity = maturity_;
    }

    // administrator
    // function setWETHcontract(address _newAddress) external onlyOwner {
    //     _WETHcontract = ERC20(_newAddress); // is this safe...?
    // }
    // function renounceOwnership() public virtual override onlyOwner {
    //     require(false, "Owner of this contract can not be nullable.");
    // }
    // function _transferOwnership(address _newOwner) internal override onlyOwner {
    //     require(_newOwner != owner(), "Transfer to self is not allowed.");
    //     require(_totalWETH <= _WETHcontract.allowance(address(this), _newOwner), "WETH transfer is not allowed due to allowance.");
    //     _WETHcontract.transferFrom(address(this), _newOwner, _totalWETH);
    //     super.transferOwnership(_newOwner);
    // }

    // getters
    function getTotalWETH() external view returns(uint) {
        return _totalWETH;
    }
    function getDepositWETH(address _depositor) external view returns(uint) {
        return _depositWETH[_depositor];
    }

    // setters
    function addDeposit(uint amount_) external onlyOffering beforeOfferClose {
        // transfer weth from msg.sender to this contract
        require(amount_ != 0, "Deposit amount must be positive.");
        _WETHcontract.transferFrom(msg.sender, address(this), amount_);
        _depositWETH[msg.sender] = _depositWETH[msg.sender].add(amount_);
        _totalWETH = _totalWETH.add(amount_);
        _depositors.push(msg.sender);
    }
    function _withdraw(uint amount_) private onlyOffering beforeOfferClose onlyDepositor {
        // transfer weth from this contract to msg.sender
        require(amount_ <= _depositWETH[msg.sender], "Lack of deposit amount.");
        _WETHcontract.transferFrom(address(this), msg.sender, amount_);
        _depositWETH[msg.sender] = _depositWETH[msg.sender].sub(amount_);
        _totalWETH = _totalWETH.sub(amount_);
    }
    function withdrawWETH(uint amount_) external onlyOffering beforeOfferClose onlyDepositor {
        _withdraw(amount_);
    }
    function withdrawWETH() external onlyOffering beforeOfferClose onlyDepositor {
        _withdraw(_depositWETH[msg.sender]);
    }

    // ordering
    function _makeBuyOrder() private onlyOffering {
        // make a buy-order.
        // in this function, use only 99.9999x% of weth to keep market incentive
        // this function is future work. we need to implement price control logic.
        // now, we assume that all weth is used to buy an asset.
    }
    function _cancelBuyOrder() private onlyOrdering {
    }
    function order() external onlyOffering {
        require(_offerClosingTime <= block.timestamp, "Can not stop offering before offer closing time");
        require(block.timestamp < _orderExpiration, "Order expiration is already passed.");
        require(block.timestamp < _maturity, "Maturity is already passed.");
        _makeBuyOrder();
        _state = State.Ordering;
    }
    function _checkPurchased() public onlyOrdering returns(bool) {
        if (true) {
            // when order is not matched.
            return false;
        }
        _purchasePrice = _totalWETH;
        _state = State.AssetHolding;
        return true;
    }

    // publish token
    function publishToken() external onlyOrdering {
        require(block.timestamp < _orderExpiration, "Order expiration is already passed.");
        require(block.timestamp < _maturity, "Maturity is already passed.");
        require(_checkPurchased(), "Order is not matched yet");
    }

    // sell asset
    function _makeSellOrder() private {
        // make a sell-order.
        // this function is future work. we need to implement price control logic.
    }
    function _cancellSellOrder() private {
        // cancel a sell-order.
    }
    function sellAsset() external {
        require(_state == State.AssetHolding, "Sell is available only when this contract holds an asset.");
        require(_maturity <= block.timestamp, "Selling asset is available only after maturity.");
        _makeSellOrder();
        _state = State.AssetSelling;
    }
    function updateSellOrder() external onlyAssetSelling {
        _cancellSellOrder();
        _makeSellOrder();
    }
    function checkSold() internal onlyAssetSelling returns(bool) {
        if (true) {
            // when order is not matched.
            return false;
        }
        _soldPrice = _totalWETH;
        _state = State.AssetSold;
        return true;
    }

    // redeem
    function _ifXthenY(bool x, bool y) internal pure returns(bool) {
        return !x || y;
    }
    modifier onlyRedeemable() {
        require(_ifXthenY(_state == State.Offering, _orderExpiration < block.timestamp), "Offering state contract is redeemable only after order expiry.");
        require(_ifXthenY(_state == State.Ordering, _orderExpiration < block.timestamp), "Ordering state contract is redeemable only after order expiry.");
        require(_state != State.AssetHolding, "Can not redeem before selling asset.");
        require(_state != State.AssetSelling, "Can not redeem before completing selling asset.");
        require(_state != State.Closed, "Already redeemed.");
        _;
    }
    function _refund() internal onlyRedeemable {
        require(_soldPrice != 0, "UnderlyingAsset is sold by 0 weth.");
        address maxDepositor = _depositors[0];
        uint maxDeposit = 0;
        uint nDepositors = _depositors.length;
        uint totalWETH = _totalWETH;
        require(totalWETH <= _WETHcontract.balanceOf(address(this)));
        for (uint i=0; i<nDepositors; ++i) {
            address depositor = _depositors[i];
            uint balance = _depositWETH[depositor];
            if (balance != 0) {
                if (maxDeposit < balance) {
                    maxDeposit = balance;
                    maxDepositor = depositor;
                }
                uint refundAmount = (_soldPrice * balance) / totalWETH;
                _WETHcontract.transfer(depositor, refundAmount);
                _totalWETH = _totalWETH.sub(refundAmount);
            }
        }
        {
            uint remaining = _WETHcontract.balanceOf(address(this));
            _WETHcontract.transfer(maxDepositor, remaining);
        }
    }
    function redeem() external onlyRedeemable {
        if (_ifXthenY(_state == State.Ordering, _orderExpiration < block.timestamp)) {
            _cancelBuyOrder();
        }
        _refund();
        _state = State.Closed;
    }

    // IERC20 behavior. This behavior is active only when AssetHolding state
    function totalSupply() external view override onlyAssetHolding returns (uint256) {
        return _totalWETH;
    }
    function balanceOf(address account_) external view override onlyAssetHolding returns (uint256) {
        return _depositWETH[account_];
    }
    function allowance(address owner_, address spender_) external view override onlyAssetHolding returns (uint256) {
        return _allowance[owner_][spender_];
    }
    function approve(address spender_, uint256 amount_) external override onlyAssetHolding returns (bool) {
        require(spender_ != address(0), "Null spender address");
        _allowance[msg.sender][spender_] = amount_;
        emit Approval(msg.sender, spender_, amount_);
        return true;
    }
    function _transfer(address from_, address to_, uint amount_) private  onlyAssetHolding returns (bool) {
        require(to_ != address(0), "Null from address");
        require(to_ != address(0), "Null target address");
        require(from_ != to_, "Transfer to himself does not make sence.");
        require(amount_ <= _depositWETH[from_], "Fail to transfer token because of lack of tokens.");
        require(amount_ <= _allowance[from_][to_], "Too much amount is tried to transfer");
        if (_allowance[from_][to_] != type(uint).max) {
            _allowance[from_][to_] = _allowance[msg.sender][to_].sub(amount_);
        }
        _depositWETH[to_] = _depositWETH[to_].add(amount_);
        _depositWETH[from_] = _depositWETH[from_].sub(amount_);
        _depositors.push(to_);
        emit Transfer(from_, to_, amount_);
        return true;        
    }
    function transfer(address to_, uint256 amount_) external override onlyAssetHolding returns (bool) {
        return _transfer(msg.sender, to_, amount_);
    }
    function transferFrom(address from_, address to_, uint amount_) external override onlyAssetHolding returns (bool) {
        return _transfer(from_, to_, amount_);
    }
}
