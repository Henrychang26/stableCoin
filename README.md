1. (Relative Stability) Anchored or Pegged -> $1.00
   1. Chainlink Price feed
   2. Set a function to exchange ETH/BTC -> $$$
2. Stability Mechanism (Minting): Algorithmic (Decentalized)
   1. People can only mint stable coin with enough collateral (coded)
3. Collateral: Exogenous (Crypto)
   1. WETH
   2. WBTC

$100 DSC => $200 (WETH) WETH:$10 X 20
=> WETH : $5 = $5 X 20 = $100 healthfactor: 0.5

                                            $200 collateral

User: Collateral $140 (WETH, WBTC combined) $100 DSC => healthfactor 0.7
has nothing(no collateral or DSC)

Liquidator: spend $50 DSC to burn, receive $55 in collateral

protocol keeps $30

user $50 DSC collateral $85 => 0.85

Case2
User: Collateral $80 (WETH, WBTC combined) $100 DSC => healthfactor 0.4
has nothing(no collateral or DSC)

Liquidator: spend $100 DSC to burn, receive $110 in collateral

protocol keeps $30
