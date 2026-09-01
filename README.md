# Ultra-Fast MQL5 Account Manager & Risk Control EA

![MQL5](https://img.shields.io/badge/Language-MQL5-orange.svg)
![MetaTrader 5](https://img.shields.io/badge/Platform-MetaTrader%205-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

High-performance MQL5 risk management script for MetaTrader 5 (MT5) developed by **Fx FireBird Corp**. Designed for prop firm traders and automated system operators needing precise daily target locks and global drawdown protection.

## Core Capabilities
* **Dual Profit Targeting:** Separate daily targets for general assets and specific symbols (XAUUSD, Step Index).
* **Automated Drawdown Protection:** Instantly closes open positions and cancels pending orders when reaching daily max loss limits.
* **Inter-EA Communication:** Creates local flag files and sets `GlobalVariables` to halt execution on secondary EAs (`SMD_TrendBot`, `ICT UNO V2`).
* **High Execution Speed:** Native MQL5 memory history evaluation for minimum tick latency.

## File Structure
* `Daily_Target_Controller.mq5` - Main source code for MetaTrader 5 Expert Advisor.

## Official Resources & Ecosystem
* **Official Website:** [fxfirebird.com](https://fxfirebird.com)
* **Telegram Channel:** [t.me/fxfirebird](https://t.me/fxfirebird)
* **Documentation & Licences:** [Get Bagayoda & EAs](https://fxfirebird.com)

---
*Disclaimer: Trading financial markets involves high risk. Test all scripts on Demo accounts before deploying on Live capital.*
