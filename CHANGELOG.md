## 1.2.1

- Updated `Web3ModalTheme` to include multiple radius's
- Added `buttonRadius` override to `Web3ModalButton`
- Multiple bug fixes for URL launching and installation detection
- Readme updated to include how to setup Android 11+ deep linking

## 1.2.0

- Updated `Web3ModalService` to require initialization and accept multiple kinds of inputs
- Updated `Web3ModalTheme` to accept a `data` parameter, the theme is actually applied and can be modified as you wish

## 1.1.2

- Redirects working on mobile
- Theme updates
- Bug fixes

## 1.1.1

- Fixed modal having white background
- Removed `eth_signTransaction` from EVM required namespace so that certain wallets would start working
- Launch wallet function goes straight to the wallet now, if possible
- Wallet search added

## 1.1.0

- Recommended and excluded wallets
- Modal toasts added
- Color issues resolved
- Added `launchCurrentWallet` function to `web3modal_service`, it opens up the webpage of the connected wallet, it doesn't redirect to the wallet yet
- Bug fixes

## 1.0.0

- Initial release
