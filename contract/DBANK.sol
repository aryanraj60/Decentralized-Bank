//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface cETH {
    //defining the functions of Compound we will be using-
    function mint() external payable; //to deposit to compound

    function redeem(uint redeemTokens) external returns (uint); //to withdraw from Compound

    //following two functions are to know how much you'll able to withdraw
    function exchangeRateStored() external view returns (uint);

    function balanceOf(address owner) external view returns (uint256 balance);

    function balanceOfUnderlying(address owner) external returns (uint);
}

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function transfer(address recepient, uint256 amount)
        external
        returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recepient,
        uint256 amount
    ) external returns (bool);
}

interface UniswapRouter {
    function WETH() external pure returns (address);

    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);
}

contract DBank {
    cETH ceth;

    constructor(address compoundETHAddress) {
        ceth = cETH(compoundETHAddress);
    }

    mapping(address => uint) compoundETH;

    address UNISWAP_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    UniswapRouter uniswap = UniswapRouter(UNISWAP_ROUTER_ADDRESS);

    function addMoney() public payable {
        uint compETHBeforeMint = ceth.balanceOf(address(this));
        ceth.mint{value: msg.value}();
        uint compETHAfterMint = ceth.balanceOf(address(this));
        uint compoundETHAmountOfUser = compETHAfterMint - compETHBeforeMint;

        if (msg.sender != address(this)) {
            compoundETH[msg.sender] += compoundETHAmountOfUser;
        }
    }

    function addMoneyErc20Token(address erc20TokenAddress) public {
        IERC20 erc20 = IERC20(erc20TokenAddress);
        uint allowedToken = erc20.allowance(msg.sender, address(this));
        erc20.transferFrom(msg.sender, address(this), allowedToken);

        address token = erc20TokenAddress;
        uint amountETHMin = 0;
        address to = address(this);
        uint deadline = block.timestamp + (24 * 60 * 60);

        //approve uniswap to take tokens this contract has sent by the user
        erc20.approve(UNISWAP_ROUTER_ADDRESS, allowedToken);

        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = uniswap.WETH();
        uniswap.swapExactTokensForETH(
            allowedToken,
            amountETHMin,
            path,
            to,
            deadline
        );
        uint compETHBeforeMint = ceth.balanceOf(address(this));
        this.addMoney{value: address(this).balance}();
        uint compETHAfterMint = ceth.balanceOf(address(this));
        uint userCompoundEth = compETHAfterMint - compETHBeforeMint;
        compoundETH[msg.sender] += userCompoundEth;
    }

    function getContractTokenBalance(address erc20TokenAddress)
        public
        view
        returns (uint)
    {
        IERC20 erc20 = IERC20(erc20TokenAddress);
        return erc20.allowance(msg.sender, address(this));
    }

    function getCethBalance(address _cEthOwner) public view returns (uint) {
        return compoundETH[_cEthOwner];
    }

    //Amount after interest
    function getBalance(address _owner) public view returns (uint) {
        return compoundETH[_owner] * (ceth.exchangeRateStored() / 1e18);
    }

    function withdraw() public {
        require(compoundETH[msg.sender] > 0, "you haven't deposit anything.");
        ceth.redeem(compoundETH[msg.sender]);
        payable(msg.sender).transfer(getBalance(msg.sender));
        compoundETH[msg.sender] = 0;
    }

    function withdrawInErc20(address tokenAddress) public {
        require(compoundETH[msg.sender] > 0, "you haven't deposit anything.");
        address token = tokenAddress;
        address[] memory path = new address[](2);
        path[0] = uniswap.WETH();
        path[1] = token;
        uint amountETHMin = 0;
        address to = msg.sender;
        uint deadline = block.timestamp + (24 * 60 * 60);
        ceth.redeem(compoundETH[msg.sender]);
        uniswap.swapExactETHForTokens{value: getBalance(msg.sender)}(
            amountETHMin,
            path,
            to,
            deadline
        );
        compoundETH[msg.sender] = 0;
    }

    function getContractEthBalance() public view returns (uint) {
        return address(this).balance;
    }

    receive() external payable {}
}
