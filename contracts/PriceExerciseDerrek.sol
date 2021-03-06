//doesn't work; compare to google doc version

pragma solidity ^0.6.6;

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.6/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.6/vendor/Ownable.sol";

contract PriceExercise is ChainlinkClient {
    bool public priceFeedGreater;
    int256 public storedPrice;

    constructor(
        address _oracle,
        string memory _jobId,
        uint256 _fee,
        address _link,
        address _priceFeed
    ) public {
        //from APIConsumer.sol
        if (_link == address(0)) {
            setPublicChainlinkToken();
        } else {
            setChainlinkToken(_link);
        }
        // oracle = 0x2f90A6D021db21e1B2A077c5a37B3C7E75D15b7e;
        // jobId = "29fa9aa13bf1468788b7cc4a500a45b8";
        // fee = 0.1 * 10 ** 18; // 0.1 LINK
        oracle = _oracle;
        jobId = stringToBytes32(_jobId);
        fee = _fee;

        //from PriceConsumerV3.sol
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    function getLatestPrice() public view returns (int256) {
        (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        return price;
    }

    function requestPriceData() public returns (bytes32 requestId) {
        Chainlink.Request memory request = buildChainlinkRequest(
            jobId,
            address(this),
            this.fulfill.selector
        );

        // Set the URL to perform the GET request on
        request.add(
            "get",
            "https://min-api.cryptocompare.com/data/pricemultifull?fsyms=BTC&tsyms=USD"
        );

        // Set the path to find the desired data in the API response, where the response format is:
        // {"RAW":
        //   {"BTC":
        //    {"USD":
        //     {
        //      "PRICE": xxx.xxx,
        //     }
        //    }
        //   }
        //  }
        request.add("path", "RAW.BTC.USD.PRICE");

        // Multiply the result by 1000000000000000000 to remove decimals
        int256 timesAmount = 10**18;
        request.addInt("times", timesAmount);

        // Sends the request
        return sendChainlinkRequestTo(oracle, request, fee);
    }

    function fulfill(bytes32 _requestId, int256 _price)
        public
        recordChainlinkFulfillment(_requestId)
    {
        storedPrice = _price;

        if (getLatestPrice() > storedPrice) {
            priceFeedGreater = true;
        } else {
            priceFeedGreater = false;
        }
    }
}
