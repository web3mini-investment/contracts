// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CollectiveInvestmentSchemeV2 is ERC20 {
    // using 
    using SafeMath for uint;

    // enums
    enum State { Offering, Ordering, AssetHolding, AssetSelling, AssetSold, Closed }

    // events
    event StateTransition(State from, State to);

    // external contracts
    ERC20 private _WETHcontract;    // how to control this safely...?

    // --- vvv fields vvv ---
    // scheme info
    State private _state;
    uint private _offerClosingTime;
    uint private _orderExpiration;
    uint private _maturity;
    address private _underlyingAsset; // this must be hidden in some manner...

    // execution result
    uint private _purchasePrice;
    uint private _soldPrice;

    // deposit info
    address[] private _depositors;

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
    modifier onlyAssetSold() {
        require(_state == State.AssetSold, "Available only when asset sold.");
        _;
    }
    modifier onlyDepositor() {
        require(super.balanceOf(msg.sender) != 0, "Only depositor can call.");
        _;
    }

    constructor(
        address WETHcontractAddress_,
        address underlyingAsset_,
        uint offerClosingTime_,
        uint orderExpiration_,
        uint maturity_,
        string memory tokanName_,
        string memory tokenSymbol_
    )
        ERC20(tokanName_, tokenSymbol_)
    {
        require(WETHcontractAddress_ != address(0));
        require(underlyingAsset_ != address(0));
        require(block.timestamp <= offerClosingTime_, "Offer closing time must be in future.");
        require(offerClosingTime_ <= block.timestamp + 90 days , "Offer closing time is too future.");
        require(offerClosingTime_ <= orderExpiration_, "Order expiration must be after offer closing time.");
        require(orderExpiration_ <= offerClosingTime_ + 90 days, "Order expiration is too future of offer closing time.");
        require(offerClosingTime_ <= maturity_, "Maturity must be after offer closing time.");
        require(maturity_ <= offerClosingTime_ + 180 days, "Maturity is too future of offer closing time.");
        _WETHcontract = ERC20(WETHcontractAddress_);
        _underlyingAsset = underlyingAsset_;
        _offerClosingTime = offerClosingTime_;
        _orderExpiration = orderExpiration_;
        _maturity = maturity_;
    }

    // [getters] ---------------------------------------------------------------
    
    /**
     * @dev State of this contract, which is either of
     * { Offering, Ordering, AssetHolding, AssetSelling, AssetSold, Closed }
     *
     *  - Offering: Investor can deposit tokens into this contract
     *  - Ordering: Trying to buy an asset
     *  - AssetHolding: Order is success and token of this contract is published.
     *  - AssetSelling: Token transfer is stopped. Trying to sell the asset
     *  - AssetSold: Asset is sold. It is prepared to refund.
     *  - Closed: This contract(fund) is closed.
     *
     * State transitions:
     *  Offering --> Ordering --> AssetHolding --> AssetSelling --> AssetSold --> Closed
     *      |            |                                                           A
     *      v            v                                                           |
     *      --------------------------------------------------------------------------
     *    
     */
    function state() external view returns(State) {
        return _state;
    }
    /**
     * @dev A limit time when investors deposit their WETH tokens
     */
    function offerClosingTime() external view returns(uint) {
        return _offerClosingTime;
    }
    /**
     * @dev An expiration time of an order on the market 
     */
    function orderExpiration() external view returns(uint) {
        return _orderExpiration;
    }
    /**
     * @dev Maturity of this contract. After this, an asset is tried to sell.
     * (In this sence, 'maturity' may not be suitable.)
     */
    function maturity() external view returns(uint) {
        return _maturity;
    }
    /**
     * @dev An address of underlying asset to be invested.
     */
    function underlyingAsset() external view returns(address) {
        return _underlyingAsset;
    }

    /**
     * @dev ERC20.totalSupply() is used as accumulated deposit under Offering state.
     */
    function totalDepositWETH() external view onlyOffering returns(uint) {
        return super.totalSupply();
    }
    /**
     * @dev ERC20.balanceOf(_depositor) is used as deposit of _depositor under Offering state.
     */
    function depositWETH(address _depositor) external view onlyOffering returns(uint) {
        return super.balanceOf(_depositor);
    }
    
    // [setters] ---------------------------------------------------------------

    /**
     * @dev Deposit WETH into this contract with this method.
     * posted amount is stored as token amount of ERC20.
     */
    function addDeposit(uint amount_) external onlyOffering beforeOfferClose {
        require(amount_ != 0, "Deposit amount must be positive.");
        _WETHcontract.transferFrom(msg.sender, address(this), amount_);
        super._mint(msg.sender, amount_);
        _depositors.push(msg.sender);
    }
    /**
     * @dev Implementation of withdraw methods.
     * withdrawn amount burns tokens of ERC20.
     */
    function _withdraw(uint amount_) private onlyOffering beforeOfferClose onlyDepositor {
        // transfer weth from this contract to msg.sender
        require(amount_ <= super.balanceOf(msg.sender), "Lack of deposit amount.");
        _WETHcontract.transferFrom(address(this), msg.sender, amount_);
        super._burn(msg.sender, amount_);
    }
    /**
     * @dev Withdraw WETH from this contract with this method.
     */
    function withdrawWETH(uint amount_) external onlyOffering beforeOfferClose onlyDepositor {
        _withdraw(amount_);
    }
    /**
     * @dev Withdraw all WETH from this contract.
     */
    function withdrawWETH() external onlyOffering beforeOfferClose onlyDepositor {
        _withdraw(super.balanceOf(msg.sender));
    }

    // [state transition] ordering ---------------------------------------------

    /**
     * @dev Implementation of making buy order.
     * TODO: Implement this. (or consider more sophisticated stragegy...)
     */
    function _makeBuyOrder() private onlyOffering {
        // future work
    }
    /**
     * @dev Cancel buy order
     * TODO: Implement this. (or consider more sophisticated stragegy...)
     */
    function _cancelBuyOrder() private onlyOrdering {
        // future work
    }
    /**
     * @dev Make a buy order of an asset.
     * after making an order, state of this contract becomes Ordering.
     */
    function makeBuyOrder() external onlyOffering {
        require(_offerClosingTime <= block.timestamp, "Can not make buy offer before offer-closing-time");
        require(block.timestamp < _orderExpiration, "Order expiration is already passed.");
        require(block.timestamp < _maturity, "Maturity is already passed.");
        _makeBuyOrder();
        State originalState = _state;
        _state = State.Ordering;
        emit StateTransition(originalState, _state);
    }

    // [state transition] publish token ----------------------------------------

    /**
     * @dev Check if the buy order matches or not.
     * if order matched, change state into AssetHolding
     */
    function _checkPurchased() private onlyOrdering returns(bool) {
        if (true) {
            // when order is not matched.
            return false;
        }
        _purchasePrice = super.totalSupply();
        State originalState = _state;
        _state = State.AssetHolding;
        emit StateTransition(originalState, _state);
        return true;
    }
    /**
     * @dev Publish token.
     * in this contract, 'publish token' is implement just an state transition.
     * (_checkPurchased method may update state)
     * see IERC20 behavior of this contract.
     */
    function publishToken() external onlyOrdering {
        require(block.timestamp < _orderExpiration, "Order expiration is already passed.");
        require(block.timestamp < _maturity, "Maturity is already passed.");
        require(_checkPurchased(), "Order is not matched yet");
    }

    // sell asset [state transition] -------------------------------------------

    /**
     * @dev Implementation of making sell order.
     * TODO: Implement this. but to do so, we need to consider how to control sell price.
     */
    function _makeSellOrder() private {
        // future work
    }
    /**
     * @dev Cancel sell order
     * TODO: Implement this. (or consider more sophisticated stragegy...)
     */
    function _cancellSellOrder() private {
        // future work
    }
    /**
     * @dev Make an sell order of underlying asset. this method is available only after 'maturity'.
     * after this method, state of this contract becomes AssetSelling. 
     */
    function sellAsset() external onlyAssetHolding {
        require(_maturity <= block.timestamp, "Selling asset is available only after maturity.");
        _makeSellOrder();
        State originalState = _state;
        _state = State.AssetSelling;
        emit StateTransition(originalState, _state);
    }

    // [state transition] redeem -----------------------------------------------

    /**
     * @dev Check if the sell order matches or not.
     * if order matched, change state into AssetSold
     */    
    function _checkSold() internal onlyAssetSelling returns(bool) {
        if (true) {
            // when order is not matched.
            return false;
        }
        _soldPrice = super.totalSupply();
        State originalState = _state;
        _state = State.AssetSold;
        emit StateTransition(originalState, _state);
        return true;
    }
    /**
     * @dev proposition X => Y (if X then Y)
     */
    function _ifThen(bool x, bool y) private pure returns(bool) {
        return !x || y;
    }
    modifier onlyRedeemable() {
        require(_ifThen(_state == State.Offering, _offerClosingTime < block.timestamp), "Offering state contract is redeemable only after offer closing time.");
        require(_ifThen(_state == State.Ordering, _orderExpiration < block.timestamp), "Ordering state contract is redeemable only after order expiry.");
        require(_ifThen(_state == State.AssetSold, true));  // always true. exposition only
        require(_state != State.AssetHolding, "Can not redeem before selling asset.");
        require(_state != State.AssetSelling, "Can not redeem before completing selling asset.");
        require(_state != State.Closed, "Already redeemed.");
        _;
    }
    /**
     * @dev Implementation of refund.
     * sold price is distributed for investors.
     * when some WETH is remained, it will be returned to max-token-holder.
     * after redeemed, state becomes Closed.
     */
    function _refundAfterAssetSold() private onlyAssetSold {
        if (_soldPrice == 0 || _depositors.length == 0) {
            // unfortunately, underlying-asset is sold by 0 weth...
            // hence, refunding is not occured...
            return;
        }
        address maxTokenHolder = _depositors[0];
        uint maxToken = 0;
        uint nDepositors = _depositors.length;

        // copy totalSupply of token because tokens will be burned and totalSupply will also change. 
        uint totalWETH = super.totalSupply();
        uint heldWETH = _soldPrice;
        require(heldWETH <= _WETHcontract.balanceOf(address(this)));
        for (uint i=0; i<nDepositors; ++i) {
            address depositor = _depositors[i];
            uint balance = super.balanceOf(depositor);
            if (balance != 0) {
                if (maxToken < balance) {
                    maxToken = balance;
                    maxTokenHolder = depositor;
                }
                uint refundAmount = (_soldPrice * balance) / totalWETH;
                _WETHcontract.transfer(depositor, refundAmount);
                heldWETH -= refundAmount;
                super._burn(depositor, balance);
            }
        }
        // max token holder gets remained WETH
        _WETHcontract.transfer(maxTokenHolder, heldWETH);

        State originalState = _state;
        _state = State.Closed;
        emit StateTransition(originalState, _state);
    }
    /**
     * @dev Implementation of refund.
     * this method is expected to be called before asset buying.
     * in this case, ERC20.totalSupply() is equivalent to sum of deposit of investors.
     * after redeemed, state becomes Closed.
     */
    function _refundAfterBeforeAssetHolding() private onlyRedeemable {
        require(_state == State.Offering || _state == State.Ordering);

        if (_soldPrice == 0 || _depositors.length == 0) {
            // unfortunately, underlying-asset is sold by 0 weth...
            // hence, refunding is not occured...
            return;
        }
        require(super.totalSupply() <= _WETHcontract.balanceOf(address(this)));
        for (uint i=0; i<_depositors.length; ++i) {
            address depositor = _depositors[i];
            uint balance = super.balanceOf(depositor);
            if (balance != 0) {
                _WETHcontract.transfer(depositor, balance);
                super._burn(depositor, balance);
            }
        }
        State originalState = _state;
        _state = State.Closed;
        emit StateTransition(originalState, _state);
    }
    /**
     * @dev Redeem.
     * When asset is bought and sold, sold price is shared by investors.
     * When asset is not bought, deposits are returned.
     */
    function redeem() external onlyRedeemable {
        if (_ifThen(_state == State.Ordering, _orderExpiration < block.timestamp)) {
            _cancelBuyOrder();
        }
        if (_state == State.AssetSold) {
            _refundAfterAssetSold();
        }
        else {
            _refundAfterBeforeAssetHolding();
        }
    }


    // [IERC20] The followings make sence only when AssetHolding state ---------
    function totalSupply() public view override returns (uint256) {
        if (_state == State.AssetHolding) {
            return super.totalSupply();
        }
        else {
            return 0;
        }
    }
    function balanceOf(address account_) public view override returns (uint256) {
        if (_state == State.AssetHolding) {
            return super.balanceOf(account_);
        }
        else {
            return 0;
        }
    }
    function allowance(address owner_, address spender_) public view override returns (uint256) {
        if (_state == State.AssetHolding) {
            return super.allowance(owner_, spender_);
        }
        else {
            return 0;
        }
    }
    function approve(address spender_, uint256 amount_) public override returns (bool) {
        require(_state == State.AssetHolding, "Approve is available only under AssetHolding state");
        return super.approve(spender_, amount_);
    }
    function transfer(address to_, uint256 amount_) public override returns (bool) {
        require(_state == State.AssetHolding, "Transfer is available only under AssetHolding state");
        return super.transfer(to_, amount_);
    }
    function transferFrom(address from_, address to_, uint amount_) public override returns (bool) {
        require(_state == State.AssetHolding, "Transfer is available only under AssetHolding state");
        return super.transferFrom(from_, to_, amount_);
    }    
}
