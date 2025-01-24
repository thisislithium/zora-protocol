// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IZoraFactory} from "./interfaces/IZoraFactory.sol";
import {Coin} from "./Coin.sol";

/*
    $$$$$$$$\  $$$$$$\  $$$$$$$\   $$$$$$\     $$$$$$$$\  $$$$$$\   $$$$$$\ $$$$$$$$\  $$$$$$\  $$$$$$$\  $$\     $$\ 
         $$  |$$  __$$\ $$  __$$\ $$  __$$\    $$  _____|$$  __$$\ $$  __$$\\__$$  __|$$  __$$\ $$  __$$\ \$$\   $$  |
        $$  / $$ /  $$ |$$ |  $$ |$$ /  $$ |   $$ |      $$ /  $$ |$$ /  \__|  $$ |   $$ /  $$ |$$ |  $$ | \$$\ $$  / 
       $$  /  $$ |  $$ |$$$$$$$  |$$$$$$$$ |   $$$$$\    $$$$$$$$ |$$ |        $$ |   $$ |  $$ |$$$$$$$  |  \$$$$  /  
      $$  /   $$ |  $$ |$$  __$$< $$  __$$ |   $$  __|   $$  __$$ |$$ |        $$ |   $$ |  $$ |$$  __$$<    \$$  /   
     $$  /    $$ |  $$ |$$ |  $$ |$$ |  $$ |   $$ |      $$ |  $$ |$$ |  $$\   $$ |   $$ |  $$ |$$ |  $$ |    $$ |    
    $$$$$$$$\  $$$$$$  |$$ |  $$ |$$ |  $$ |   $$ |      $$ |  $$ |\$$$$$$  |  $$ |    $$$$$$  |$$ |  $$ |    $$ |    
    \________| \______/ \__|  \__|\__|  \__|   \__|      \__|  \__| \______/   \__|    \______/ \__|  \__|    \__|    
*/
contract ZoraFactoryImpl is IZoraFactory, UUPSUpgradeable, ReentrancyGuardUpgradeable, OwnableUpgradeable {
    using SafeERC20 for IERC20;

    /// @notice The coin contract implementation address
    address public immutable coinImpl;

    constructor(address _coinImpl) initializer {
        coinImpl = _coinImpl;
    }

    /// @notice Creates a new coin contract
    /// @param payoutRecipient The recipient of creator reward payouts; this can be updated by an owner
    /// @param owners The list of addresses that will be able to manage the coin's payout address and metadata uri
    /// @param uri The coin metadata uri
    /// @param name The name of the coin
    /// @param symbol The symbol of the coin
    /// @param platformReferrer The address to receive platform referral rewards
    /// @param currency The address of the trading currency; address(0) for ETH/WETH
    /// @param tickLower The lower tick for the Uniswap V3 LP position; ignored for ETH/WETH pairs
    /// @param orderSize The order size for the first buy; must match msg.value for ETH/WETH pairs
    function deploy(
        address payoutRecipient,
        address[] memory owners,
        string memory uri,
        string memory name,
        string memory symbol,
        address platformReferrer,
        address currency,
        int24 tickLower,
        uint256 orderSize
    ) public payable nonReentrant returns (address) {
        bytes32 salt = _generateSalt(payoutRecipient, uri);

        Coin coin = Coin(payable(Clones.cloneDeterministic(coinImpl, salt)));

        coin.initialize(payoutRecipient, owners, uri, name, symbol, platformReferrer, currency, tickLower);

        _handleFirstOrder(coin, orderSize);

        emit WowTokenCreated(
            address(this),
            payoutRecipient,
            coin.platformReferrer(),
            coin.protocolRewardRecipient(),
            address(0),
            uri,
            name,
            symbol,
            address(coin),
            coin.poolAddress()
        );

        emit CoinCreated(
            msg.sender,
            payoutRecipient,
            payoutRecipient,
            coin.platformReferrer(),
            coin.currency(),
            uri,
            name,
            symbol,
            address(coin),
            coin.poolAddress()
        );

        return address(coin);
    }

    /// @notice DEPRECATED: For backwards compatibility with legacy Wow
    /// @dev This defaults to an ETH-based coin with the given `creator` as the payout recipient and only owner
    /// @param creator The creator address
    /// @param platformReferrer The platform referrer address
    /// @param tokenURI The coin uri
    /// @param name The coin name
    /// @param symbol The coin symbol
    function deploy(
        address creator,
        address platformReferrer,
        string memory tokenURI,
        string memory name,
        string memory symbol
    ) external payable returns (address) {
        address[] memory initialOwners = new address[](1);
        initialOwners[0] = creator;

        address coin = deploy(creator, initialOwners, tokenURI, name, symbol, platformReferrer, address(0), 0, msg.value);

        return coin;
    }

    /// @dev Generates a unique salt for deterministic deployment
    function _generateSalt(address _creator, string memory _tokenURI) internal view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    msg.sender,
                    _creator,
                    keccak256(abi.encodePacked(_tokenURI)),
                    block.coinbase,
                    block.number,
                    block.prevrandao,
                    block.timestamp,
                    tx.gasprice,
                    tx.origin
                )
            );
    }

    /// @dev Handles the first buy of a newly created coin
    /// @param coin The newly created coin contract
    /// @param orderSize The size of the first buy order; must match msg.value for ETH/WETH pairs
    function _handleFirstOrder(Coin coin, uint256 orderSize) internal {
        if (msg.value > 0 || orderSize > 0) {
            address currency = coin.currency();
            address payoutRecipient = coin.payoutRecipient();

            if (currency != coin.WETH()) {
                if (msg.value != 0) {
                    revert EthTransferInvalid();
                }

                _handleIncomingCurrency(currency, orderSize);

                IERC20(currency).approve(address(coin), orderSize);

                coin.buy(payoutRecipient, orderSize, 0, 0, address(0));
            } else {
                coin.buy{value: msg.value}(payoutRecipient, orderSize, 0, 0, address(0));
            }
        }
    }

    /// @dev Safely transfers ERC20 tokens from the caller to this contract to be sent to the newly created coin
    /// @param currency The ERC20 token address to transfer
    /// @param orderSize The amount of tokens to transfer for the order
    function _handleIncomingCurrency(address currency, uint256 orderSize) internal {
        uint256 beforeBalance = IERC20(currency).balanceOf(address(this));
        IERC20(currency).safeTransferFrom(msg.sender, address(this), orderSize);
        uint256 afterBalance = IERC20(currency).balanceOf(address(this));

        if ((afterBalance - beforeBalance) != orderSize) {
            revert ERC20TransferAmountMismatch();
        }
    }

    /// @notice Initializes the factory proxy contract
    /// @param initialOwner Address of the contract owner
    /// @dev Can only be called once due to initializer modifier
    function initialize(address initialOwner) external initializer {
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __Ownable_init(initialOwner);
    }

    /// @notice The implementation address of the factory contract
    function implementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    /// @dev Authorizes an upgrade to a new implementation
    /// @param newImpl The new implementation address
    function _authorizeUpgrade(address newImpl) internal override onlyOwner {}
}
