// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.0 < 0.9.0;
pragma experimental ABIEncoderV2;

// ██████   █████  ███    ██ ██████   ██████  ███    ███ ██ ███████ ███████ ██████      ███    ██ ███████ ████████ ██     ██  ██████  ██████  ██   ██ 
// ██   ██ ██   ██ ████   ██ ██   ██ ██    ██ ████  ████ ██    ███  ██      ██   ██     ████   ██ ██         ██    ██     ██ ██    ██ ██   ██ ██  ██  
// ██████  ███████ ██ ██  ██ ██   ██ ██    ██ ██ ████ ██ ██   ███   █████   ██████      ██ ██  ██ █████      ██    ██  █  ██ ██    ██ ██████  █████   
// ██   ██ ██   ██ ██  ██ ██ ██   ██ ██    ██ ██  ██  ██ ██  ███    ██      ██   ██     ██  ██ ██ ██         ██    ██ ███ ██ ██    ██ ██   ██ ██  ██  
// ██   ██ ██   ██ ██   ████ ██████   ██████  ██      ██ ██ ███████ ███████ ██   ██     ██   ████ ███████    ██     ███ ███   ██████  ██   ██ ██   ██ 
                                                                                                                                                   
// ██████   █████  ██ ██   ██    ██     ██████  ██████   █████  ██     ██ 
// ██   ██ ██   ██ ██ ██    ██  ██      ██   ██ ██   ██ ██   ██ ██     ██ 
// ██   ██ ███████ ██ ██     ████       ██   ██ ██████  ███████ ██  █  ██ 
// ██   ██ ██   ██ ██ ██      ██        ██   ██ ██   ██ ██   ██ ██ ███ ██ 
// ██████  ██   ██ ██ ███████ ██        ██████  ██   ██ ██   ██  ███ ███  

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

interface mintRNDDToken {
    function mint(address receiver, uint amount) external;
}

contract RandomizerDailyDraw is Context, Ownable, ReentrancyGuard, VRFConsumerBaseV2, KeeperCompatible {
    using SafeERC20 for IERC20;
    
    IERC20 private immutable randomDAOToken;   // RANDOM TOKENS ARE RECLAIMABLE AFTER THE ROUND ENDS
    IERC20 private immutable rnddUtilityToken;  // RNDD TOKENS ARE BURNED ON EVERY USE 1 RNDD = 1 TICKET
    IERC721Enumerable private immutable nftMetaPass; // META GAME PASS NFTS - DAILY PRIVATE NFT DAILY DRAW

    VRFCoordinatorV2Interface COORDINATOR;
    LinkTokenInterface LINKTOKEN;

    event DrawOpen(uint256 gameRoundNr);
    event DrawClosed(uint256 gameRoundNr, uint256 totalTickets, uint256 totalPlayers);
    event DrawCompleted(uint256 gameRoundNr, uint256[50] winningTicketsNr, address[50] winners);
    event TicketsPurchased(address token, address player, uint256 tokens, bytes data);
    event Claim(address claimer, uint256 rnAmount);

    enum Status {
        Open,           // The daily draw is open for ticket purchases
        Closed,         // The daily draw is no longer open for ticket purchases
        Completed       // The daily draw in this round has closed and the random lucky tickets have been drawn
    }

    struct Round {
        Status gameStatus;                       // Daily Draw Rounds Status
        uint256 requestId;                          // Round Chainlink VRF Request ID
        uint256 startDate;                          // Round Start Time
        uint256 endDate;                            // Round End Date
        uint256 totalUniquePlayers;                 // Total Unique Players in active round
        uint256 totalTickets;                       // Total Tickets Bought in active round
        uint256[] randomResult;                     // Chainlink VRF Random Result (hex number)
        uint256[50] luckyTicketsDAO;                // Lucky Tickets are drawn every round (you can win multiple times with 1 ticket)
        uint256[50] luckyTicketsNFT;                // Lucky Addresses of Lucky Winnings Tickets
        address[50] winnersDAO;                     // Lucky Addresses of Lucky Winnings Tickets
        address[50] winnersNFT;                     // Lucky Addresses of Lucky Winnings Tickets
        mapping (uint256 => address) ticketOwner;   // Players Addresses from their Ticket Numbers 
        mapping (address => uint256) totalRANDOM;   // Total RANDOM Contributed in active round
        mapping (address => uint256) totalRNDD;     // Total RNDD Contributed in active round
        mapping (address => bool) isUnique;         // Check if Player is Unique in current round
    }

    mapping(uint => Round) public rounds;

    // CHAINLINK VRF V2
    bytes32 public vrfKeyHash = 0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;
    address public vrfLinkToken = 0x01BE23585060835E02B77ef475b0Cc51aA1e0709;
    address public vrfCoordinator = 0x6168499c0cFfCaCD319c818142124B7A15E857ab;
    address public treasury; // GNOSIS TREASURY FOR REWARDS AND BURNING MECHANISM

    // DAILY JACKPOT ROUND
    uint256 public round;
    uint256 public drawFrequency = 1 minutes; // 1 day
    uint256 public drawEarlyClosing = 10 seconds; // 5 minutes
    uint256 public unclaimedTokens;            // total RANDOM Tokens that are Claimable
    uint256 public rnEntry = 1e18;             // 1 RANDOM per Ticket that is reclaimable at the end of the round
    uint256 public rnddEntry = 1e18;           // 1 RNDD Token per Ticket that get's burned after it is used
    uint16 private requestConfirmations = 3;   // Longest Chain of Blocks after which Chainlink VRF makes the Random Hex Request 
    uint32 private callbackGasLimit = 300000;  // Amount of gas used for Chainlink Keepers Network calling Chainlink VRF V2 Randomness Function
    uint32 private numWords = 2;               // Total Random Numbers Requested by the Chainlink Verifiable Randomness Function used by both draws
    uint32 private gamesSplitPot = 50;         // Daily there are 100 winners made in 2 draws (50 Winners for RANDOM & RNDD) & (50 Winners for Meta Pass Holders)
    uint64 public subscriptionId;              // Chainlink Subscription ID
    bool public finalRound;                    // Last round after 10 years

    // 0x52757Be8e15b57FCC3B17998196D0bf238f5613d, 500000000000000000000000000 in GNOSIS SAFE approve 50% of total supply
    // "0xd478220182812C63d8A23D1fd3B889771207B40d", "0x6e60DEe75b6fA14f6AA5Cc190f84364AcD16ad63", "0xdA5586DbB8bC749571964f06139B46F3aB3F0CB4", "0xe6F7C7caF678A3B7aFb93891907873E88F4FD4AC"
    constructor(IERC20 _randomDAOToken, IERC20 _rnddUtilityToken, IERC721Enumerable _nftMetaPass, address _treasury) VRFConsumerBaseV2(vrfCoordinator) {
        randomDAOToken = _randomDAOToken;
        rnddUtilityToken = _rnddUtilityToken;
        nftMetaPass = _nftMetaPass;
        treasury = _treasury;
        round = 1;
        rounds[round].gameStatus = Status.Open;
        rounds[round].startDate = block.timestamp;
        rounds[round].endDate = block.timestamp + drawFrequency;
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        LINKTOKEN = LinkTokenInterface(vrfLinkToken);
        createNewSubscription();
        // require(topUpSubscription(1000000000000000000), "test");
    }

    // Create a new subscription when the contract is initially deployed.
    function createNewSubscription() private onlyOwner {
        subscriptionId = COORDINATOR.createSubscription();
        COORDINATOR.addConsumer(subscriptionId, address(this));
    }

    // Assumes this contract owns link. 1000000000000000000 = 1 LINK
    function topUpSubscription(uint256 amount) external onlyOwner {
        LINKTOKEN.transferAndCall(address(COORDINATOR), amount, abi.encode(subscriptionId));
    }

    // Add a consumer contract to the subscription.
    function addConsumer(address consumerAddress) external onlyOwner {
        COORDINATOR.addConsumer(subscriptionId, consumerAddress);
    }

    // Remove a consumer contract from the subscription.
    function removeConsumer(address consumerAddress) external onlyOwner {
        COORDINATOR.removeConsumer(subscriptionId, consumerAddress);
    }

    // Cancel the subscription and send the remaining LINK to a wallet address.
    function cancelSubscription(address receivingWallet) external onlyOwner {
        COORDINATOR.cancelSubscription(subscriptionId, receivingWallet);
        subscriptionId = 0;
    }

    // Set Gnosis Treasury Wallet Address
    function setTreasuryAddress (address _treasury) public onlyOwner returns (bool) {
        treasury = _treasury;
        return true;
    }

    // Used to withdraw remaining LINK Tokens after ~10 years of Daily Games.
    function withdrawLink(uint256 amount, address to) external onlyOwner {
        LINKTOKEN.transfer(to, amount);
    }

    // Helper function used to withdraw remaining RANDOM Tokens after all Daily Games have finished.
    function withdrawRandomTokens() external onlyOwner {
        require(randomDAOToken.transfer(_msgSender(), randomDAOToken.balanceOf(address(this)) - unclaimedTokens), "Unable to transfer");
    }

    /**
     * @dev Get 1 Ticket Price with RANDOM Tokens.
     * @custom:time every hour entry price increases by 1 RANDOM Tokens for each chance
     */
    function getRandomPrice() public view returns (uint ticketPrice) {
        uint TICKET_PRICE_INCREASE = 1; // 1 RANDOM token every hour
        uint SECONDS_PER_HOUR = 60 * 60; // 3600 seconds
        uint HOUR_DIFFERENCE = (block.timestamp - rounds[round].startDate) / SECONDS_PER_HOUR;
        return rnEntry + (TICKET_PRICE_INCREASE * (HOUR_DIFFERENCE * 1e18));
    }

    /**
     * @dev Get Round Winners
     * returns luckyTickets and luckyWinners
     */
    function getWinners(uint roundNr) public view returns (
        uint256[50] memory luckyTicketDAO, 
        address[50] memory luckyWinnerDAO, 
        uint256[50] memory luckyTicketNFT, 
        address[50] memory luckyWinnerNFT
    ) {
        return (
            rounds[roundNr].luckyTicketsDAO, rounds[roundNr].winnersDAO, // DAO
            rounds[roundNr].luckyTicketsNFT, rounds[roundNr].winnersNFT // DAO
        );
    }

    /**
     * @dev Claim locked tokens + rewards from a specific round.
     * @param roundNr Desired round number.
     * returns claimed RANDOM Tokens.
     */
    function claim(uint roundNr) public nonReentrant returns (uint256 claimedRANDOM) {
        require(roundNr > round, "Wait until round finishes");
        uint randomDAOTokens = 0;
        
        if(rounds[roundNr].totalRANDOM[_msgSender()] > 0) {
            randomDAOTokens = rounds[roundNr].totalRANDOM[_msgSender()];
            rounds[roundNr].totalRANDOM[_msgSender()] = 0;
            randomDAOToken.safeTransfer(_msgSender(), randomDAOTokens);
            unclaimedTokens -= randomDAOTokens;
        }

        emit Claim(_msgSender(), randomDAOTokens);
        return randomDAOTokens;
    }

    /**
     * @dev Claim locked tokens + rewards from all rounds.
     * @return claimedRANDOM and claimnedRNDD
     */
    function claimAll() public nonReentrant returns (uint256 claimedRANDOM) {
        uint randomDAOTokens = 0;
        for(uint i = 1; i <= round; i++) {
            if (rounds[i].totalRANDOM[_msgSender()] > 0) {
                uint rn = rounds[i].totalRANDOM[_msgSender()];
                rounds[i].totalRANDOM[_msgSender()] = 0;
                randomDAOTokens += rn;
            }
        }

        randomDAOToken.safeTransfer(_msgSender(), randomDAOTokens);
        unclaimedTokens -= randomDAOTokens;

        emit Claim(_msgSender(), randomDAOTokens);
        return randomDAOTokens;
    }

    /**
     * @dev Helper function that is used to display winner addresses, contributions and lucky bonuses won
     * @param roundNr Desired round number.
     * @return bool Function returns round winners statistics.
     */
    function roundStats(uint roundNr) view public returns (address[] memory, uint[] memory, uint[] memory) {
        // RANDOM GOVERNANCE TOKEN
        uint playersLength = rounds[roundNr].winnersDAO.length;
        uint[] memory contribution = new uint[](playersLength);
        uint[] memory totalRandomWinner = new uint[](playersLength);
        address[] memory addresses = new address[](playersLength);

        for(uint i = 0; i < playersLength; i++){
            addresses[i] = rounds[roundNr].winnersDAO[i];
            contribution[i] = rounds[roundNr].totalRANDOM[addresses[i]];
            totalRandomWinner[i] = rounds[roundNr].totalRNDD[addresses[i]];
        }

        return (addresses, contribution, totalRandomWinner);
    }

    /**
     * @dev Helper function that is used to display winner addresses, contributions and lucky bonuses won
     * @param roundNr Desired round number.
     * @return bool Function returns round winners statistics.
     */
    function roundStatsNFTs(uint roundNr) view public returns (address[] memory, uint[] memory, uint[] memory) {
        // NFT META PASSS
        uint nftPlayersLength = rounds[roundNr].winnersNFT.length;
        uint[] memory contributionNFTs = new uint[](nftPlayersLength);
        uint[] memory totalRandomWinnerNFTs = new uint[](nftPlayersLength);
        address[] memory addressesNFTs = new address[](nftPlayersLength);

        for(uint i = 0; i < nftPlayersLength; i++){
            addressesNFTs[i] = rounds[roundNr].winnersNFT[i];
            contributionNFTs[i] = rounds[roundNr].totalRANDOM[addressesNFTs[i]];
            totalRandomWinnerNFTs[i] = rounds[roundNr].totalRNDD[addressesNFTs[i]];
        }

        return (addressesNFTs, contributionNFTs, totalRandomWinnerNFTs);
    }

    function getClaimableTokens(uint256 nr) public view returns (uint rn, uint256 rndd) {
        rn = rounds[nr].totalRANDOM[_msgSender()];
        rndd = rounds[nr].totalRNDD[_msgSender()];
    }

    /**
     * @dev Helper function for ChainLink VRF that extracts multiple random winning tickets from random entropy sources.
     * return array of winning tickets.
     */
    function expand(uint256 _randomValue, uint256 _totalWinningTickets, uint256 _totalWinners) public pure returns (uint256[] memory expandedValues) {
        expandedValues = new uint256[](_totalWinners);
        for (uint256 i = 0; i < _totalWinners; i++) {
            expandedValues[i] = (uint256(keccak256(abi.encode(_randomValue, i))) % _totalWinningTickets) + 1;
        }
        return expandedValues;
    }

    // function expand(uint256[] memory randomValue, uint256 totalWinningTickets, uint256 totalWinners) public pure returns (uint256[] memory expandedValues) {
    //     expandedValues = new uint256[](totalWinners);
    //     for (uint256 i = 0; i < totalWinners; i++) {
    //         expandedValues[i] = (uint256(keccak256(abi.encode(randomValue[i], i))) % totalWinningTickets) + 1;
    //     }
    //     return expandedValues;
    // }

    /**
     * @dev Callback function used by VRF Coordinator to draw winners, announce and setup next round.
     * @param requestId VRF Coordinator request.
     * @param randomness VRF Coordinator random result.
     */
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomness) internal override {
        uint256 totalNFTs = getGamePassTotalSupply();
        uint256[] memory winningTicketsNFTs = expand(randomness[0], totalNFTs, gamesSplitPot);
        uint256[] memory winningTicketsDAO = expand(randomness[1], rounds[round].totalTickets, gamesSplitPot);
        (uint256 toReward, uint256 toBurn, bool isFinalRound) = rewardBurnRatio();

        // FUTURE TO-DO 
        // MAKE SURE ALL SLOTS ARE FILLED FOR DAILY TOKENS DRAW
        // 100 DAILY WINNING TICKETS AND IF THERE ARE NOT ATLEAST 50 TICKETS
        // BOUGHT WITH RANDOM TOKEN AND RNDD UTILITY TOKEN WE COULD PUSH THE REMAINDER
        // REWARDS FOR THE META PASSES SO THEY GET MORE THAN 50 CHANCES PER TICKET EACH DAY

        // TRANSFER TOKENS FROM TREASURY TO THE DAILY DRAW CONTRACT
        // (bool successDeposit,) = address(randomDAOToken).call(abi.encodeWithSignature("transferFrom(address,address,uint256)",treasury, address(this), (toReward * 100) + toBurn));
        // require(successDeposit,"burn FAIL");

        // 100 DAILY WINNERS
        for (uint i = 0; i < gamesSplitPot; i++) {
            // DRAW DAO GOVERNANCE - 50 WINNERS (270 RANDOM Tokens per ticket and 100 RNDD)
            address winnerAddressDAO = rounds[round].ticketOwner[winningTicketsDAO[i]];
            rounds[round].winnersDAO[i] = winnerAddressDAO;
            rounds[round].luckyTicketsDAO[i] = winningTicketsDAO[i];
            rounds[round].totalRANDOM[winnerAddressDAO] = rounds[round].totalRANDOM[winnerAddressDAO] + toReward;
            rounds[round].totalRNDD[winnerAddressDAO] = rounds[round].totalRNDD[winnerAddressDAO] + 100;
            // randomDAOToken.safeTransferFrom(treasury, winnerAddressDAO, toReward);
            // mintRNDDToken(address(rnddUtilityToken)).mint(winnerAddressDAO, 100e18);

            // DRAW META GAME PASS - 50 WINNERS (270 RANDOM Tokens per ticket and 100 RNDD)
            address winnerAddressNFT = getGamePassOwnerByID(winningTicketsNFTs[i]);
            rounds[round].winnersNFT[i] = winnerAddressNFT;
            rounds[round].luckyTicketsNFT[i] = winningTicketsNFTs[i];
            rounds[round].totalRANDOM[winnerAddressNFT] = rounds[round].totalRANDOM[winnerAddressNFT] + toReward;
            rounds[round].totalRNDD[winnerAddressNFT] = rounds[round].totalRNDD[winnerAddressNFT] + 100;
            
            // randomDAOToken.safeTransferFrom(treasury, winnerAddressNFT, toReward);
            // mintRNDDToken(address(rnddUtilityToken)).mint(winnerAddressNFT, 100e18);
        }
        
        unclaimedTokens += toReward * 100;
        // bool transferTokens = randomDAOToken.transferFrom(treasury, address(this), toBurn);
        // require(transferTokens, "transferFrom treasury FAIL");

        // (bool success,) = address(randomDAOToken).call(abi.encodeWithSignature("burn(uint256)",toBurn));
        // require(success,"burn FAIL");

        rounds[round].gameStatus = Status.Completed;
        rounds[round].randomResult = randomness;
        rounds[round].requestId = requestId;
        emit DrawCompleted(round, rounds[round].luckyTicketsDAO, rounds[round].winnersDAO);

        if(isFinalRound) {
            finalRound = true;
        } else {
            // INITIATE NEXT ROUND
            round = round + 1;
            rounds[round].gameStatus = Status.Open;
            rounds[round].startDate = block.timestamp;
            rounds[round].endDate = rounds[round].startDate + drawFrequency;
            emit DrawOpen(round);
        }

    }

    function getGamePassOwnerByID(uint256 _id) public view returns (address tokenOwner) {
        return IERC721Enumerable(nftMetaPass).ownerOf(_id);
    }

    function getGamePassTotalSupply() public view returns (uint256 totalSupply) {
        return IERC721Enumerable(nftMetaPass).totalSupply();
    }

    function rewardBurnRatio() public view returns (uint256 toReward, uint256 toBurn, bool isFinalRound) {
        uint256 treasuryBalance = randomDAOToken.balanceOf(address(treasury)); // aproval check
        uint256 reward = 27400 * 1e18; // 27.400 RANDOM Tokens / 100 Winning Tickets = 274 RANDOM (50 DAO, 50 NFT) Daily Draw
        if(reward * 2 <= treasuryBalance) {
            toReward = reward / (gamesSplitPot * 2); // 1% annual reward (~270 RANDOM Tokens per ticket * 100 Winners)
            toBurn = reward * 5; // 5% annual burn (137.000 RANDOM Tokens Burned every day)
            isFinalRound = false;
        } else if (reward * 2 >= treasuryBalance) {
            toReward = treasuryBalance / 2 / (gamesSplitPot * 2);
            toBurn = treasuryBalance / 2;
            isFinalRound = true;
        }
    }

    /**
     * @dev ChainLink Keepers function that checks if round draw conditions have been met and initiates draw when they are true.
     * return bool upkeepNeeded if random winning tickets are ready to be drawn.
     * return bytes performData contain the current encoded round number.
     */
    function checkUpkeep(bytes calldata /* checkData */) external view override returns (bool upkeepNeeded, bytes memory performData) {
        upkeepNeeded = 
            rounds[round].endDate - drawEarlyClosing <= block.timestamp &&
            rounds[round].requestId == 0 &&
            rounds[round].gameStatus == Status.Open && 
            rounds[round].gameStatus != Status.Completed;
            // rounds[round].totalTickets >= 10;
        performData = abi.encode(round);
    }

    /**
     * @dev ChainLink Keepers function that is executed by the Chainlink Keeper.
     * @param performData encoded round number sent over from checkUpKeep
     */
    function performUpkeep(bytes calldata performData) external override {
        uint256 verifyRound = abi.decode(performData, (uint256));
        require(verifyRound == round, "Round mismatch.");
        require(
            rounds[round].endDate - drawEarlyClosing <= block.timestamp &&
            rounds[round].requestId == 0 &&
            rounds[round].gameStatus == Status.Open && 
            rounds[round].gameStatus != Status.Completed,
            // rounds[round].totalTickets >= 10, 
            "Could not draw winnings tickets."
        );
        rounds[round].gameStatus == Status.Closed;
        emit DrawClosed(round, rounds[round].totalTickets, rounds[round].totalUniquePlayers);
        COORDINATOR.requestRandomWords(
            vrfKeyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords // numWords
        );
    }

    /**
     * @dev Helper function used to view ticket number ownership.
     * @param roundNr The round from which we want to inspect ticket slots
     * @param nr The ticket slot numbers
     * return totalTickets the total Number tickets purchased in the round selected
     * return ticketOwner the address of the player that owns the round ticket
     */
    function getTicketNumber(uint roundNr, uint nr) public view returns(uint totalTickets, address ticketOwner) {
        return (rounds[roundNr].totalTickets, rounds[roundNr].ticketOwner[nr]);
    }

    function getCurrentTime() public view returns (uint time) { time = block.timestamp; }
    function getCurrentBlockTime() public view returns (uint blockNr) { blockNr = block.number; }
    function getCurrentRoundTimeDiff() public view returns (uint time) { time = rounds[round].endDate - block.timestamp; }

    /**
     * @dev ERC677 TokenFallback Function.
     * @param _wallet The player address that sent tokens to the RANDOM Daily Draw Contract.
     * @param _value The amount of tokens sent by the player to the RANDOM Daily Draw Contract.
     * @param _data  The transaction metadata.
     */
    function onTokenTransfer(address _wallet, uint256 _value, bytes memory _data) public {
        require(finalRound == false, "The daily RANDOM Daily Draw has successfully distributed all 401.500.000 RANDOM Tokens!");
        uint ticketPrice = getRandomPrice();
        buyTicket(_wallet, _value, ticketPrice, round, _data);
    }

    function buyTicket(address _wallet, uint256 _value, uint256 _rnEntryPrice, uint256 _round, bytes memory _data) private {    
        // HIDRATE UNIQUE PLAYERS IN CURRENT ROUND
        if(rounds[_round].isUnique[_wallet] == false) {
            rounds[_round].isUnique[_wallet] = true;
            rounds[_round].totalUniquePlayers = rounds[_round].totalUniquePlayers + 1;
        }
        // BUY TICKET WITH RANDOM
        if(_msgSender() == address(randomDAOToken)) {
            require(_value % _rnEntryPrice == 0, "RANDOM Ticket Price increases 1 RANDOM every hour.");
            require(_value / _rnEntryPrice <= 250, "Max 250 Tickets can be reserved at once using RANDOM Tokens.");
            _addTickets(_wallet, _value / _rnEntryPrice);
            rounds[_round].totalRANDOM[_wallet] = rounds[_round].totalRANDOM[_wallet] + _value;
            unclaimedTokens += _value;
            emit TicketsPurchased(address(randomDAOToken), _wallet, _value, _data);
        // BUY TICKET WITH RNDD
        } else if (_msgSender() == address(rnddUtilityToken)) {
            require(_value % rnddEntry == 0, "1 RNDD Token = 1 Chance at any time.");
            require(_value / rnddEntry <= 250, "Max 250 Tickets can be reserved at once using RNDD Tokens.");
            _addTickets(_wallet, _value / rnddEntry);
            rounds[_round].totalRNDD[_wallet] = rounds[_round].totalRNDD[_wallet] + _value;
            (bool success,) = address(rnddUtilityToken).call(abi.encodeWithSignature("burn(uint256)",_value));
            require(success, "burn FAIL");
            emit TicketsPurchased(address(rnddUtilityToken), _wallet, _value, _data);
        } else {
            revert("Provided amounts are not valid.");
        }
    }

    /**
     * @dev Helper function called by ERC677 onTokenTransfer function to calculate ticket slots for player and keep count of total tickets bought in the current round. 
     * @param _wallet The player address that sent tokens to the RANDOM Daily Draw Contract.
     * @param _totalTickets The amount of tokens sent by the player to the RANDOM Daily Draw Contract.
     */
    function _addTickets(address _wallet, uint _totalTickets) private {
        Round storage activeRound = rounds[round];
        uint total = activeRound.totalTickets;
        for(uint i = 1; i <= _totalTickets; i++){
            activeRound.ticketOwner[total + i] = _wallet;
        }
        activeRound.totalTickets = total + _totalTickets;
    }

    function destroy() public onlyOwner {
        // cancelSubscription(owner());
        selfdestruct(payable(owner()));
    }

}