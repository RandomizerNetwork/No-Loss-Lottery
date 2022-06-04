// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.0 < 0.9.0;
pragma experimental ABIEncoderV2;

// ██████   █████  ███    ██ ██████   ██████  ███    ███ ██ ███████ ███████ ██████   
// ██   ██ ██   ██ ████   ██ ██   ██ ██    ██ ████  ████ ██    ███  ██      ██   ██  
// ██████  ███████ ██ ██  ██ ██   ██ ██    ██ ██ ████ ██ ██   ███   █████   ██████   
// ██   ██ ██   ██ ██  ██ ██ ██   ██ ██    ██ ██  ██  ██ ██  ███    ██      ██   ██  
// ██   ██ ██   ██ ██   ████ ██████   ██████  ██      ██ ██ ███████ ███████ ██   ██  

// ███    ██ ███████ ████████ ██     ██  ██████  ██████  ██   ██ 
// ████   ██ ██         ██    ██     ██ ██    ██ ██   ██ ██  ██  
// ██ ██  ██ █████      ██    ██  █  ██ ██    ██ ██████  █████   
// ██  ██ ██ ██         ██    ██ ███ ██ ██    ██ ██   ██ ██  ██  
// ██   ████ ███████    ██     ███ ███   ██████  ██   ██ ██   ██                  

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

contract RandomizerDailyDeflationaryDraw is Context, Ownable, ReentrancyGuard, VRFConsumerBaseV2, KeeperCompatible {
    using SafeERC20 for IERC20;
    
    IERC20 private immutable randomDAOToken;         // RANDOM TOKENS ARE RECLAIMABLE AFTER THE ROUND ENDS
    IERC721Enumerable private immutable nftMetaPass; // PRIVATE META GAME PASS DAILY DRAW

    VRFCoordinatorV2Interface COORDINATOR;
    LinkTokenInterface LINKTOKEN;

    event DrawOpen(uint256 gameRoundNr);
    event DrawClosed(uint256 gameRoundNr, uint256 totalRoundTickets, uint256 totalPlayers);
    event DrawCompleted(uint256 gameRoundNr, uint256[50] winningTicketsNr, address[50] winners);
    event TicketsPurchased(address player, uint256 tokens, bytes data);
    event Claim(address claimer, uint256 rnAmount);

    enum Status {
        Open,           // The daily draw is open for ticket purchases
        Closed,         // The daily draw is no longer open for ticket purchases
        Completed       // The daily draw in this round has closed and the random lucky tickets have been drawn
    }

    struct Round {
        Status gameStatus;                            // Daily Draw Rounds Status
        uint256 requestId;                            // Round Chainlink VRF Request ID
        uint256 startDate;                            // Round Start Time
        uint256 endDate;                              // Round End Date
        uint256 totalUniquePlayers;                   // Total Unique Players in active round
        uint256 totalRoundTickets;                    // Total Tickets Bought in active round
        uint256[] randomResult;                       // Chainlink VRF Random Result (hex number)
        uint256[50] luckyTicketsDAO;                  // Lucky Tickets are drawn every round (you can win multiple times with 1 ticket)
        uint256[50] luckyTicketsNFT;                  // Lucky Addresses of Lucky Winnings Tickets
        address[50] winnersDAO;                       // Lucky Addresses of Lucky Winnings Tickets
        address[50] winnersNFT;                       // Lucky Addresses of Lucky Winnings Tickets
        mapping (uint256 => address) ticketsOwner;    // Players Addresses from their Ticket Numbers 
        mapping (address => uint256) ticketsTotal;    // Total RANDOM Contributed in active round
        mapping (address => uint256) ticketsBurned;   // Total BURN Contributed in active round
        mapping (address => bool) isUnique;           // Check if Player is Unique in current round
    }

    mapping (uint => Round) public rounds;
    mapping (address => uint256) public claimableTokens;     // Total Claimable RANDOM Governace Tokens
    mapping (address => uint256) public bonusTickets;        // Total Burnable Bonus Tickets at a 1:1 rate

    // DAILY JACKPOT ROUND
    bool public finalRound;
    uint256 public round;                         // Active Round
    uint256 public drawFrequency = 1 minutes;     // 1 day
    uint256 public drawEarlyClosing = 10 seconds; // 5 minutes
    uint256 public unclaimedTokens;               // total RANDOM Tokens that are Claimable
    uint256 private randomEntry = 1e18;           // 1 RANDOM per Ticket that is reclaimable at the end of the round
    uint64  private subscriptionId = 5124;        // Chainlink Subscription ID
    uint32  private callbackGasLimit = 300000;    // Amount of gas used for Chainlink Keepers Network calling Chainlink VRF V2 Randomness Function
    uint32  private numWords = 2;                 // Total Random Numbers Requested by the Chainlink Verifiable Randomness Function used by both draws
    uint32  private gamesSplitPot = 50;           // Daily there are 100 winners made in 2 draws (50 Winners for RANDOM & BURN) & (50 Winners for Meta Pass Holders)
    uint16  private requestConfirmations = 3;     // Longest Chain of Blocks after which Chainlink VRF makes the Random Hex Request 
    address private treasury;
    address private vrfLinkToken = 0x01BE23585060835E02B77ef475b0Cc51aA1e0709;
    address private vrfCoordinator = 0x6168499c0cFfCaCD319c818142124B7A15E857ab;
    bytes32 private vrfKeyHash = 0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;

    // 0x52757Be8e15b57FCC3B17998196D0bf238f5613d, 500000000000000000000000000 in GNOSIS SAFE approve 50% of total supply
    // "0xd9145CCE52D386f254917e481eB44e9943F39138", "0xd8b934580fcE35a11B58C6D73aDeE468a2833fa8", "0xe6F7C7caF678A3B7aFb93891907873E88F4FD4AC"
    constructor(IERC20 _randomDAOToken, IERC721Enumerable _nftMetaPass, address _treasury) VRFConsumerBaseV2(vrfCoordinator) {
        randomDAOToken = _randomDAOToken;
        nftMetaPass = _nftMetaPass;
        treasury = _treasury;
        round = 1;
        rounds[round].gameStatus = Status.Open;
        rounds[round].startDate = block.timestamp;
        rounds[round].endDate = block.timestamp + drawFrequency;
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        LINKTOKEN = LinkTokenInterface(vrfLinkToken);
    }

    /**
     * @dev Claim locked tokens + rewards from a specific round.
     * returns claimed RANDOM Tokens.
     */
    function claim() external nonReentrant returns (uint256 claimedRANDOM) {
        uint randomDAOTokens = claimableTokens[_msgSender()];
        claimableTokens[_msgSender()] = 0;
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
            contribution[i] = rounds[roundNr].ticketsTotal[addresses[i]];
            totalRandomWinner[i] = rounds[roundNr].ticketsBurned[addresses[i]];
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
            contributionNFTs[i] = rounds[roundNr].ticketsTotal[addressesNFTs[i]];
            totalRandomWinnerNFTs[i] = rounds[roundNr].ticketsBurned[addressesNFTs[i]];
        }

        return (addressesNFTs, contributionNFTs, totalRandomWinnerNFTs);
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

    /**
     * @dev Callback function used by VRF Coordinator to draw winners, announce and setup next round.
     * @param requestId VRF Coordinator request.
     * @param randomness VRF Coordinator random result.
     */
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomness) internal override {
        uint256 totalNFTs = getGamePassTotalSupply();
        uint256[] memory winningTicketsNFTs = expand(randomness[0], totalNFTs, gamesSplitPot);
        uint256[] memory winningTicketsDAO = expand(randomness[1], rounds[round].totalRoundTickets, gamesSplitPot);
        (uint256 toReward, uint256 toBurn, bool isFinalRound) = rewardBurnRatio();

        // FUTURE TO-DO 
        // MAKE SURE ALL SLOTS ARE FILLED FOR DAILY TOKENS DRAW
        // 100 DAILY WINNING TICKETS AND IF THERE ARE NOT ATLEAST 50 TICKETS
        // BOUGHT WITH RANDOM TOKEN AND BURN UTILITY TOKEN WE COULD PUSH THE REMAINDER
        // REWARDS FOR THE META PASSES SO THEY GET MORE THAN 50 CHANCES PER TICKET EACH DAY

        // TRANSFER TOKENS FROM TREASURY TO THE DAILY DRAW CONTRACT
        // (bool successDeposit,) = address(randomDAOToken).call(abi.encodeWithSignature("transferFrom(address,address,uint256)",treasury, address(this), (toReward * 100) + toBurn));
        // require(successDeposit,"burn FAIL");

        // 100 DAILY WINNERS
        for (uint i = 0; i < gamesSplitPot; i++) {
            // DRAW DAO GOVERNANCE - 50 WINNERS (270 RANDOM Tokens per ticket and 100 BURN)
            address winnerAddressDAO = rounds[round].ticketsOwner[winningTicketsDAO[i]];
            rounds[round].winnersDAO[i] = winnerAddressDAO;
            rounds[round].luckyTicketsDAO[i] = winningTicketsDAO[i];
            // rounds[round].ticketsTotal[winnerAddressDAO] = rounds[round].ticketsTotal[winnerAddressDAO] + toReward;
            // rounds[round].ticketsBurned[winnerAddressDAO] = rounds[round].ticketsBurned[winnerAddressDAO] + 100e18;

            claimableTokens[_msgSender()] = claimableTokens[_msgSender()] + rounds[round].ticketsTotal[winnerAddressDAO] + toReward;
            bonusTickets[_msgSender()] = bonusTickets[_msgSender()] + rounds[round].ticketsBurned[winnerAddressDAO] + 100e18;

            // mapping (address => uint256) claimableTokens;     // Total Claimable RANDOM Governace Tokens
            // mapping (address => uint256) bonusTickets;        // Total Burnable Bonus Tickets at a 1:1 rate


            // randomDAOToken.safeTransferFrom(treasury, winnerAddressDAO, toReward);
            // mintBURNToken(address(rnddUtilityToken)).mint(winnerAddressDAO, 100e18);

            // DRAW META GAME PASS - 50 WINNERS (270 RANDOM Tokens per ticket and 100 BURN)
            address winnerAddressNFT = getGamePassOwnerByID(winningTicketsNFTs[i]);
            rounds[round].winnersNFT[i] = winnerAddressNFT;
            rounds[round].luckyTicketsNFT[i] = winningTicketsNFTs[i];
            // rounds[round].ticketsTotal[winnerAddressNFT] = rounds[round].ticketsTotal[winnerAddressNFT] + toReward;
            // rounds[round].ticketsBurned[winnerAddressNFT] = rounds[round].ticketsBurned[winnerAddressNFT] + 100e18;

            claimableTokens[_msgSender()] = claimableTokens[_msgSender()] + rounds[round].ticketsTotal[winnerAddressNFT] + toReward;
            bonusTickets[_msgSender()] = bonusTickets[_msgSender()] + rounds[round].ticketsBurned[winnerAddressNFT] + 100e18;
            
            // randomDAOToken.safeTransferFrom(treasury, winnerAddressNFT, toReward);
            // mintBURNToken(address(rnddUtilityToken)).mint(winnerAddressNFT, 100e18);
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
     * @dev Get 1 Ticket Price with RANDOM Tokens.
     * @custom:time every hour entry price increases by 1 RANDOM Tokens for each chance
     */
    function getRandomPrice() public view returns (uint ticketPrice) {
        uint TICKET_PRICE_INCREASE = 1; // 1 RANDOM token every hour
        uint SECONDS_PER_HOUR = 60 * 60; // 3600 seconds
        uint HOUR_DIFFERENCE = (block.timestamp - rounds[round].startDate) / SECONDS_PER_HOUR;
        return randomEntry + (TICKET_PRICE_INCREASE * (HOUR_DIFFERENCE * 1e18));
    }

    /**
     * @dev Get Round Winners
     * returns luckyTickets and luckyWinners
     */
    function getWinners(uint roundNr) public view returns (uint256[50] memory ticketDAO, address[50] memory winnerDAO, uint256[50] memory ticketNFT, address[50] memory winnerNFT) {
        return (rounds[roundNr].luckyTicketsDAO, rounds[roundNr].winnersDAO, rounds[roundNr].luckyTicketsNFT, rounds[roundNr].winnersNFT);
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
            // rounds[round].totalRoundTickets >= 10;
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
            // rounds[round].totalRoundTickets >= 10, 
            "Could not draw winnings tickets."
        );
        rounds[round].gameStatus == Status.Closed;
        emit DrawClosed(round, rounds[round].totalRoundTickets, rounds[round].totalUniquePlayers);
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
     * return totalRoundTickets the total Number tickets purchased in the round selected
     * return ticketsOwner the address of the player that owns the round ticket
     */
    function getTicketNumber(uint roundNr, uint nr) public view returns(uint totalRoundTickets, address ticketsOwner) {
        return (rounds[roundNr].totalRoundTickets, rounds[roundNr].ticketsOwner[nr]);
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
            rounds[_round].ticketsTotal[_wallet] = rounds[_round].ticketsTotal[_wallet] + _value;
            unclaimedTokens += _value;
            emit TicketsPurchased(_wallet, _value, _data);
        } else {
            revert("Provided amounts are not valid.");
        }
    }

    function buyBonusTickets(uint256 _amount) external nonReentrant {
        require(bonusTickets[_msgSender()] >= _amount, "Not enough Bonus Tickets");
        require(bonusTickets[_msgSender()] % 1e18 == 0, "1 BURN Ticket = 1 Chance at any time.");
        require(bonusTickets[_msgSender()] / 1e18 <= 250, "Max 250 Tickets at once.");
        _addTickets(_msgSender(), _amount / 1e18);
        rounds[round].ticketsBurned[_msgSender()] = rounds[round].ticketsBurned[_msgSender()] + _amount;
        bonusTickets[_msgSender()] = bonusTickets[_msgSender()] - _amount;
        emit TicketsPurchased(_msgSender(), _amount, "0x0");
    }

    /**
     * @dev Helper function called by ERC677 onTokenTransfer function to calculate ticket slots for player and keep count of total tickets bought in the current round. 
     * @param _wallet The player address that sent tokens to the RANDOM Daily Draw Contract.
     * @param _totalRoundTickets The amount of tokens sent by the player to the RANDOM Daily Draw Contract.
     */
    function _addTickets(address _wallet, uint _totalRoundTickets) private {
        Round storage activeRound = rounds[round];
        uint total = activeRound.totalRoundTickets;
        for(uint i = 1; i <= _totalRoundTickets; i++){
            activeRound.ticketsOwner[total + i] = _wallet;
        }
        activeRound.totalRoundTickets = total + _totalRoundTickets;
    }

    // Set Gnosis Treasury Wallet Address
    function setTreasuryAddress(address _treasury) public onlyOwner returns (bool) {
        treasury = _treasury;
        return true;
    }

    // Helper function used to withdraw remaining RANDOM Tokens by the DAO
    function withdrawRandomTokens() external onlyOwner {
        require(randomDAOToken.transfer(_msgSender(), randomDAOToken.balanceOf(address(this)) - unclaimedTokens), "Unable to transfer");
    }

    function destroy() public onlyOwner {
        // cancelSubscription(owner());
        selfdestruct(payable(owner()));
    }

}