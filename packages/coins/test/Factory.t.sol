// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./utils/BaseTest.sol";

contract FactoryTest is BaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_constructor() public view {
        assertEq(factory.coinImpl(), address(coinImpl));
        assertEq(factory.owner(), users.factoryOwner);
    }

    function test_deploy_no_eth() public {
        address[] memory owners = new address[](1);
        owners[0] = users.creator;

        vm.prank(users.creator);
        coin = Coin(
            payable(
                factory.deploy(users.creator, owners, "https://test2.com", "Test2 Token", "TEST2", users.platformReferrer, address(weth), LP_TICK_LOWER_WETH, 0)
            )
        );
        pool = IUniswapV3Pool(coin.poolAddress());
        vm.label(address(coin), "COIN");
        vm.label(address(pool), "POOL");

        uint160 sqrtPriceX96 = pool.slot0().sqrtPriceX96;
        uint256 poolCoinBalance = coin.balanceOf(address(pool));
        uint256 poolEthBalance = weth.balanceOf(address(pool));

        console.log("POOL_TOKEN_0: ", pool.token0());
        console.log("POOL_TOKEN_1: ", pool.token1());
        console.log("POOL_SQRT_PRICE_X96: ", sqrtPriceX96);
        console.log("");
        console.log("POOL_COIN_BALANCE: ", poolCoinBalance);
        console.log("POOL_ETH_BALANCE: ", poolEthBalance);
        console.log("");

        assertEq(coin.payoutRecipient(), users.creator, "payoutRecipient");
        assertEq(coin.protocolRewardRecipient(), users.feeRecipient, "protocolRewardRecipient");
        assertEq(coin.platformReferrer(), users.platformReferrer, "platformReferrer");
        assertEq(coin.tokenURI(), "https://test2.com", "tokenURI");
        assertEq(coin.name(), "Test2 Token", "name");
        assertEq(coin.symbol(), "TEST2", "symbol");
        assertEq(coin.currency(), address(weth), "currency");
        assertEq(coin.totalSupply(), 1_000_000_000e18, "totalSupply");
        assertEq(coin.balanceOf(users.creator), 10_000_000e18, "balanceOf creator");
        assertGe(coin.balanceOf(users.platformReferrer), 5_000_000e18, "balanceOf platformReferrer");
        assertGe(coin.balanceOf(users.feeRecipient), 5_000_000e18, "balanceOf protocolRewardRecipient");
        assertGt(coin.balanceOf(coin.poolAddress()), 979_999_983e18, "balanceOf pool");
    }

    function test_deploy_with_eth(uint256 initialOrderSize) public {
        vm.assume(initialOrderSize > MIN_ORDER_SIZE);
        vm.assume(initialOrderSize < 10 ether);

        address[] memory owners = new address[](1);
        owners[0] = users.creator;

        vm.deal(users.creator, initialOrderSize);
        vm.prank(users.creator);
        coin = Coin(
            payable(
                factory.deploy{value: initialOrderSize}(
                    users.creator,
                    owners,
                    "https://test2.com",
                    "Test2 Token",
                    "TEST2",
                    users.platformReferrer,
                    address(weth),
                    LP_TICK_LOWER_WETH,
                    initialOrderSize
                )
            )
        );
        pool = IUniswapV3Pool(coin.poolAddress());
        vm.label(address(coin), "COIN");
        vm.label(address(pool), "POOL");

        uint160 sqrtPriceX96 = pool.slot0().sqrtPriceX96;
        uint256 poolCoinBalance = coin.balanceOf(address(pool));
        uint256 poolEthBalance = weth.balanceOf(address(pool));

        console.log("POOL_TOKEN_0: ", pool.token0());
        console.log("POOL_TOKEN_1: ", pool.token1());
        console.log("POOL_SQRT_PRICE_X96: ", sqrtPriceX96);
        console.log("");
        console.log("POOL_COIN_BALANCE: ", poolCoinBalance);
        console.log("POOL_ETH_BALANCE: ", poolEthBalance);
        console.log("");
        console.log("BUYER_COIN_BALANCE ", coin.balanceOf(users.creator) - 10_000_000e18);
    }

    function test_deploy_with_one_eth() public {
        address[] memory owners = new address[](1);
        owners[0] = users.creator;

        uint256 orderSize = 1 ether;
        vm.deal(users.creator, orderSize);

        vm.prank(users.creator);
        coin = Coin(
            payable(
                factory.deploy{value: orderSize}(
                    users.creator,
                    owners,
                    "https://test2.com",
                    "Test2 Token",
                    "TEST2",
                    users.platformReferrer,
                    address(weth),
                    LP_TICK_LOWER_WETH,
                    orderSize
                )
            )
        );
        pool = IUniswapV3Pool(coin.poolAddress());
        vm.label(address(coin), "COIN");
        vm.label(address(pool), "POOL");
    }

    function test_deploy_with_usdc() public {
        address[] memory owners = new address[](1);
        owners[0] = users.creator;

        vm.prank(users.creator);
        coin = Coin(
            payable(
                factory.deploy(
                    users.creator,
                    owners,
                    "https://testcoinusdcpair.com",
                    "Testcoinusdcpair",
                    "TESTCOINUSDCPAIR",
                    users.platformReferrer,
                    USDC_ADDRESS,
                    USDC_TICK_LOWER,
                    0
                )
            )
        );
        pool = IUniswapV3Pool(coin.poolAddress());
        vm.label(address(coin), "COIN");
        vm.label(address(pool), "POOL");

        assertEq(coin.currency(), USDC_ADDRESS, "currency");
        assertEq(coin.payoutRecipient(), users.creator, "payoutRecipient");
    }

    function test_deploy_with_usdc_revert_payout_recipient_zero() public {
        address[] memory owners = new address[](1);
        owners[0] = users.creator;

        vm.expectRevert(abi.encodeWithSelector(ICoin.AddressZero.selector));
        factory.deploy(
            address(0),
            owners,
            "https://testcoinusdcpair.com",
            "Testcoinusdcpair",
            "TESTCOINUSDCPAIR",
            users.platformReferrer,
            USDC_ADDRESS,
            USDC_TICK_LOWER,
            0
        );
    }

    function test_deploy_with_usdc_revert_one_owner_required() public {
        address[] memory owners = new address[](0);

        vm.expectRevert(abi.encodeWithSelector(MultiOwnable.OneOwnerRequired.selector));
        factory.deploy(
            users.creator,
            owners,
            "https://testcoinusdcpair.com",
            "Testcoinusdcpair",
            "TESTCOINUSDCPAIR",
            users.platformReferrer,
            USDC_ADDRESS,
            USDC_TICK_LOWER,
            0
        );
    }

    function test_deploy_with_usdc_platform_referrer_zero() public {
        address[] memory owners = new address[](1);
        owners[0] = users.creator;

        coin = Coin(
            payable(
                factory.deploy(
                    users.creator,
                    owners,
                    "https://testcoinusdcpair.com",
                    "Testcoinusdcpair",
                    "TESTCOINUSDCPAIR",
                    address(0),
                    USDC_ADDRESS,
                    USDC_TICK_LOWER,
                    0
                )
            )
        );

        assertEq(coin.platformReferrer(), coin.protocolRewardRecipient(), "platformReferrer");
    }

    function test_revert_deploy_with_invalid_currency_tick() public {
        address[] memory owners = new address[](1);
        owners[0] = users.creator;

        vm.expectRevert(abi.encodeWithSelector(ICoin.InvalidWethLowerTick.selector));
        coin = Coin(
            payable(
                factory.deploy(
                    users.creator,
                    owners,
                    "https://testcoinusdcpair.com",
                    "Testcoinusdcpair",
                    "TESTCOINUSDCPAIR",
                    users.platformReferrer,
                    address(0),
                    USDC_TICK_LOWER,
                    0
                )
            )
        );
    }

    function test_deploy_with_usdc_revert_invalid_eth_transfer() public {
        address[] memory owners = new address[](1);
        owners[0] = users.creator;

        dealUSDC(users.creator, 1);

        vm.deal(users.creator, 1e6);

        vm.prank(users.creator);
        vm.expectRevert(abi.encodeWithSelector(ICoin.EthTransferInvalid.selector));
        coin = Coin(
            payable(
                factory.deploy{value: 1e6}(
                    users.creator,
                    owners,
                    "https://testcoinusdcpair.com",
                    "Testcoinusdcpair",
                    "TESTCOINUSDCPAIR",
                    users.platformReferrer,
                    USDC_ADDRESS,
                    USDC_TICK_LOWER,
                    0
                )
            )
        );
    }

    function test_deploy_without_initial_order() public {
        address[] memory owners = new address[](1);
        owners[0] = users.creator;

        coin = Coin(
            payable(
                factory.deploy(users.creator, owners, "https://test.com", "Test Token", "TEST", users.platformReferrer, address(weth), LP_TICK_LOWER_WETH, 0)
            )
        );

        assertEq(coin.balanceOf(users.creator), 10_000_000e18, "Should only have initial creator allocation");
    }

    function test_upgrade() public {
        ZoraFactoryImpl newImpl = new ZoraFactoryImpl(address(coinImpl));

        vm.prank(users.factoryOwner);
        factory.upgradeToAndCall(address(newImpl), "");

        assertEq(factory.implementation(), address(newImpl), "implementation");
    }

    function test_revert_invalid_upgrade_impl() public {
        address newImpl = address(this);

        vm.prank(users.factoryOwner);
        vm.expectRevert(abi.encodeWithSelector(ERC1967Utils.ERC1967InvalidImplementation.selector, address(newImpl)));
        factory.upgradeToAndCall(address(newImpl), "");
    }

    function test_revert_invalid_owner() public {
        ZoraFactoryImpl newImpl = new ZoraFactoryImpl(address(coinImpl));

        vm.prank(users.creator);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, users.creator));
        factory.upgradeToAndCall(address(newImpl), "");
    }
}
