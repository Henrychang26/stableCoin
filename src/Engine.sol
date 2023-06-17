// // SPDX-License-Identifier: MIT

// pragma solidity 0.8.19;

// import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
// import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// contract Engine is ReentrancyGuard {
//     error Engine__tokenAddressesLengthDoesNotMatchPriceFeedAddreses();
//     error Engine__MoreThanZero();
//     error Engine__TokenNotAllowed();
//     error Engine__TransferFailed();
//     error Engine__HealthFactorIsBroken();
//     error DSCEngine__HealthFactorOk();
//     error DSCEngine__HealthFactorNotImproved();

//     DecentralizedStableCoin public immutable i_dsc;

//     constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, DecentralizedStableCoin _dsc) {
//         if (tokenAddresses.length != priceFeedAddresses.length) {
//             revert Engine__tokenAddressesLengthDoesNotMatchPriceFeedAddreses();
//         }
//         for (uint256 i = 0; i < tokenAddresses.length; ++i) {
//             s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
//             collateralTokens.push(tokenAddresses[i]);
//         }
//         i_dsc = _dsc;
//     }

//     //State Variables

//     uint256 private constant MIN_HEALTH_FACTOR = 1e18;
//     uint256 private constant PRICE_FEED_PRECISION = 1e10;
//     uint256 private constant ADDITIONAL_PRECISION = 1e10;
//     uint256 private constant LIQUIDATION_THRESHOLD = 50;
//     uint256 private constant LIQUIDATION_PRECISION = 1e18;

//     address[] public collateralTokens;

//     //mapping

//     mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposit;
//     mapping(address tokenAddress => address priceAddress) private s_priceFeeds;
//     mapping(address user => uint256 dscMinted) private s_totalDscMinted;

//     //Modifiers
//     modifier moreThanZero(uint256 amount) {
//         if (amount <= 0) {
//             revert Engine__MoreThanZero();
//         }
//         _;
//     }

//     modifier allowedToken(address token) {
//         if (s_priceFeeds[token] == address(0)) {
//             revert Engine__TokenNotAllowed();
//         }
//         _;
//     }

//     //Events
//     event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
//     event MintedDsc(address indexed user, uint256 indexed amount);
//     event BurnedDsc(address indexed user, uint256 indexed amount);
//     event RedeemedCollateral(address indexed from, address indexed to, address indexed token, uint256 amount);


//     function depositCollateralAndMintDsc(address collateral, uint256 collateralAmount, uint256 dscToMint) public {
//         depositCollateral(collateral, collateralAmount);
//         mintDsc(dscToMint);
//     }

//     function depositCollateral(address collateral, uint256 collateralAmount)
//         public
//         moreThanZero(collateralAmount)
//         allowedToken(collateral)
//         nonReentrant
//     {
//         s_collateralDeposit[msg.sender][collateral] += collateralAmount;
//         emit CollateralDeposited(msg.sender, collateral, collateralAmount);

//         bool success = IERC20(collateral).transferFrom(msg.sender, address(this), collateralAmount);
//         if (!success) {
//             revert Engine__TransferFailed();
//         }
//     }

//     function mintDsc(uint256 dscToMint) public moreThanZero(dscToMint) nonReentrant {
//         s_totalDscMinted[msg.sender] += dscToMint;
//         emit MintedDsc(msg.sender, dscToMint);
//         _revertIfHealthFactorIsBroken(msg.sender);
//         bool success = i_dsc.mint(msg.sender, dscToMint);
//         if (!success) {
//             revert Engine__TransferFailed();
//         }
//     }

//     function _revertIfHealthFactorIsBroken(address user) public view {
//         uint256 userHealthFactor = _healthFactor(user);
//         if (userHealthFactor < MIN_HEALTH_FACTOR) {
//             revert Engine__HealthFactorIsBroken();
//         }
//     }

//     function _healthFactor(address user) public view returns (uint256) {
//         (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
//         return _calculateHealthFactor(totalDscMinted, collateralValueInUsd);
//     }

//     function _calculateHealthFactor(uint256 totalDscMinted, uint256 collateralValueInUsd)
//         internal
//         pure
//         returns (uint256)
//     {
//         if (totalDscMinted == 0) return type(uint256).max;
//         uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / 100;
//         return (collateralAdjustedForThreshold * 1e18) / totalDscMinted;
//     }

//     function getAccountCollateralValueInUsd(address user) public view returns (uint256 totalCollateralValueInUsd) {
//         for (uint256 i = 0; i < collateralTokens.length; ++i) {
//             address token = collateralTokens[i];
//             uint256 collateralAmount = s_collateralDeposit[user][token];
//             totalCollateralValueInUsd = getUsdValue(token, collateralAmount);
//         }
//     }

//     function getUsdValue(address token, uint256 amountCollateral) public view returns (uint256) {
//         (, int256 price,,,) = AggregatorV3Interface(s_priceFeeds[token]).latestRoundData();
//         return ((uint256(price) * PRICE_FEED_PRECISION) * (amountCollateral)) / ADDITIONAL_PRECISION;
//     }

//     function _getAccountInformation(address user)
//         public
//         view
//         returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
//     {
//         totalDscMinted = s_totalDscMinted[user];
//         collateralValueInUsd = getAccountCollateralValueInUsd(user);
//     }

//     function liquidate(address collateral, address user, uint256 debtToCover)
//         public
//         moreThanZero(debtToCover)
//         allowedToken(collateral)
//         nonReentrant
//     {
//         uint256 userStartingHealthFactor = _healthFactor(user);
//         if (userStartingHealthFactor >= MIN_HEALTH_FACTOR) {
//             revert DSCEngine__HealthFactorOk();
//         }

//         uint256 tokenAmountFromDebtCovered = getUsdValue(collateral, debtToCover);
//         uint256 liquidationBonus = (tokenAmountFromDebtCovered * 10 ) / 100;

//         _redeemCollateral(collateral, tokenAmountFromDebtCovered + liquidationBonus, user, msg.sender);
//         _burnDsc(debtToCover, user,msg.sender);

//         uint256 endingUserHealthFactor = _healthFactor(user);
//         if (endingUserHealthFactor <= userStartingHealthFactor) {
//             revert DSCEngine__HealthFactorNotImproved();
//         }
//         _revertIfHealthFactorIsBroken(msg.sender);
//     }

//     function redeemCollateralForDsc(address collateral, uint256 amountToRedeem, uint256 dscToBurn) public{
//         burnDsc(dscToBurn);
//         redeemCollateral(collateral, amountToRedeem);
//         _revertIfHealthFactorIsBroken(msg.sender);
//     }

//     function redeemCollateral(address collateral, uint256 amountToRedeem)
//         public
//         moreThanZero(amountToRedeem)
//         nonReentrant
//         allowedToken(collateral)
//     {
//         _redeemCollateral(collateral, amountToRedeem, msg.sender, msg.sender);
//         _revertIfHealthFactorIsBroken(msg.sender);
//     }

//     function _redeemCollateral(address collateral, uint256 amountToRedeem, address from, address to) private {
//         s_collateralDeposit[from][collateral] -= amountToRedeem;
//         emit RedeemedCollateral(from, to, collateral, amountToRedeem);

//         bool success = IERC20(collateral).transfer(to, amountToRedeem);
//         if (!success) {
//             revert Engine__TransferFailed();
//         }
//     }

//     function burnDsc(uint256 amountToBurn) public moreThanZero(amountToBurn) nonReentrant {
//         _burnDsc(amountToBurn, msg.sender, msg.sender);
//         _revertIfHealthFactorIsBroken(msg.sender);
//     }

//     function _burnDsc(uint256 amountToBurn, address onBehalfOf, address dscFrom) private {
//          s_totalDscMinted[onBehalfOf] -= amountToBurn;

//         bool success = i_dsc.transferFrom(dscFrom, address(this), amountToBurn);
//         if(!success){
//             revert Engine__TransferFailed();
//         }
//         emit BurnedDsc(msg.sender, amountToBurn);
//         _revertIfHealthFactorIsBroken(msg.sender);
//         //Should not happen
//         i_dsc.burn(amountToBurn);
//     }
// }
