// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

/// ============ Imports ============

import "./interfaces/IERC20.sol"; // ERC20 minified interface
import "@openzeppelin/contracts/access/Ownable.sol"; // OZ: Ownership
import "@openzeppelin/contracts/token/ERC721/ERC721.sol"; // OZ: ERC721
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol"; // Chainlink VRF

/// @title MultiRaffle
/// @author Anish Agnihotri
/// @notice Multi-winner ERC721 distribution (randomized raffle & metadata)
contract MultiRaffle is Ownable, ERC721, VRFConsumerBase {

    /// ============ Structs ============

    /// @notice Metadata for range of tokenIds
    struct Metadata {
        // Starting index (inclusive)
        uint256 startIndex;
        // Ending index (exclusive)
        uint256 endIndex;
        // Randomness for range of tokens
        uint256 entropy;
    }

    /// ============ Immutable storage ============

    /// @notice LINK token
    IERC20 public immutable LINK_TOKEN;
    /// @dev Chainlink key hash
    bytes32 internal immutable KEY_HASH;
    /// @notice Cost to mint each NFT (in wei)
    uint256 public immutable MINT_COST;
    /// @notice Start time for raffle
    uint256 public immutable RAFFLE_START_TIME;
    /// @notice End time for raffle
    uint256 public immutable RAFFLE_END_TIME;
    /// @notice Available NFT supply
    uint256 public immutable AVAILABLE_SUPPLY;
    /// @notice Maximum mints per address
    uint256 public immutable MAX_PER_ADDRESS;

    /// ============ Mutable storage ============
    /// @notice LINK fee paid to oracles
    uint256 public linkFee = 2e18;
    /// @notice Entropy from Chainlink VRF
    uint256 public entropy;
    /// @notice Number of NFTs minted
    uint256 public nftCount = 0;
    /// @notice Number of raffle entries that have been shuffled
    uint256 public shuffledCount = 0;
    /// @notice Number of NFTs w/ metadata revealed
    uint256 public nftRevealedCount = 0;
    /// @notice Array of NFT metadata
    Metadata[] public metadatas;
    /// @notice Chainlink entropy collected for clearing
    bool public clearingEntropySet = false;
    /// @notice Owner has claimed raffle proceeds
    bool public proceedsClaimed = false;
    /// @notice Array of raffle entries
    address[] public raffleEntries;
    /// @notice Address to number of raffle entries
    mapping(address => uint256) public entriesPerAddress;
    /// @notice Ticket to raffle claim status
    mapping(uint256 => bool) public ticketClaimed;

    /// ============ Events ============

    /// @notice Emitted after a successful raffle entry
    /// @param user Address of raffle participant
    /// @param entries Number of entries from participant
    event RaffleEntered(address indexed user, uint256 entries);

    /// @notice Emitted after a successful partial or full shuffle
    /// @param user Address of shuffler
    /// @param numShuffled Number of entries shuffled
    event RaffleShuffled(address indexed user, uint256 numShuffled);

    /// @notice Emitted after owner claims raffle proceeds
    /// @param owner Address of owner
    /// @param amount Amount of proceeds claimed by owner
    event RaffleProceedsClaimed(address indexed owner, uint256 amount);

    /// @notice Emitted after user claims winning and/or losing raffle tickets
    /// @param user Address of claimer
    /// @param winningTickets Number of NFTs minted
    /// @param losingTickets Number of losing raffle tickets refunded
    event RaffleClaimed(address indexed user, uint256 winningTickets, uint256 losingTickets);

    /// ============ Constructor ============

    /// @notice Creates a new NFT distribution contract
    /// @param _NFT_NAME name of NFT
    /// @param _NFT_SYMBOL symbol of NFT
    /// @param _LINK_KEY_HASH key hash for LINK VRF oracle
    /// @param _LINK_ADDRESS address to LINK token
    /// @param _LINK_VRF_COORDINATOR_ADDRESS address to LINK VRF Coordinator
    /// @param _MINT_COST in wei per NFT
    /// @param _RAFFLE_START_TIME in seconds to begin raffle
    /// @param _RAFFLE_END_TIME in seconds to end raffle
    /// @param _AVAILABLE_SUPPLY total NFTs to sell
    /// @param _MAX_PER_ADDRESS maximum mints allowed per address
    constructor(
        string memory _NFT_NAME,
        string memory _NFT_SYMBOL,
        bytes32 _LINK_KEY_HASH,
        address _LINK_ADDRESS,
        address _LINK_VRF_COORDINATOR_ADDRESS,
        uint256 _MINT_COST,
        uint256 _RAFFLE_START_TIME,
        uint256 _RAFFLE_END_TIME,
        uint256 _AVAILABLE_SUPPLY,
        uint256 _MAX_PER_ADDRESS
    ) 
        VRFConsumerBase(
            _LINK_VRF_COORDINATOR_ADDRESS,
            _LINK_ADDRESS
        )
        ERC721(_NFT_NAME, _NFT_SYMBOL)
    {
        LINK_TOKEN = IERC20(_LINK_ADDRESS);
        KEY_HASH = _LINK_KEY_HASH;
        MINT_COST = _MINT_COST;
        RAFFLE_START_TIME = _RAFFLE_START_TIME;
        RAFFLE_END_TIME = _RAFFLE_END_TIME;
        AVAILABLE_SUPPLY = _AVAILABLE_SUPPLY;
        MAX_PER_ADDRESS = _MAX_PER_ADDRESS;
    }

    /// ============ Functions ============

    /// @notice Enters raffle with numTickets entries
    /// @param numTickets Number of raffle entries
    function enterRaffle(uint256 numTickets) external payable {
        // Ensure raffle is active
        require(block.timestamp >= RAFFLE_START_TIME, "Raffle not active");
        // Ensure raffle has not ended
        require(block.timestamp <= RAFFLE_END_TIME, "Raffle ended");
        // Ensure number of tickets to acquire <= max per address
        require(
            entriesPerAddress[msg.sender] + numTickets <= MAX_PER_ADDRESS, 
            "Max entries for address reached"
        );
        // Ensure sufficient raffle ticket payment
        require(msg.value == numTickets * MINT_COST, "Incorrect payment");

        // Increase mintsPerAddress to account for new raffle entries
        entriesPerAddress[msg.sender] += numTickets;

        // Add entries to array of raffle entries
        for (uint256 i = 0; i < numTickets; i++) {
            raffleEntries.push(msg.sender);
        }

        // Emit successful entry
        emit RaffleEntered(msg.sender, numTickets);
    }

    /// @notice Allows partially or fully clearing a raffle (if needed)
    /// @param numShuffles Number of indices to shuffle (max = remaining)
    function clearRaffle(uint256 numShuffles) external {
        // Ensure raffle has ended
        require(block.timestamp > RAFFLE_END_TIME, "Raffle has not ended");
        // Ensure raffle requires clearing (entries !< supply)
        require(raffleEntries.length > AVAILABLE_SUPPLY, "Raffle does not need clearing");
        // Ensure raffle requires clearing (already cleared)
        require(shuffledCount != AVAILABLE_SUPPLY, "Raffle has already been cleared");
        // Ensure number to shuffle <= required number of shuffles
        require(numShuffles <= AVAILABLE_SUPPLY - shuffledCount, "Excess indices to shuffle");
        // Ensure clearing entropy for shuffle randomness is set
        require(clearingEntropySet, "No entropy to clear raffle");

        // Run Fisher-Yates shuffle for AVAILABLE_SUPPLY
        for (uint256 i = shuffledCount; i < shuffledCount + numShuffles; i++) {
            // Generate a random index to select from
            uint256 randomIndex = i + entropy % (raffleEntries.length - i);
            // Collect the value at that random index
            address randomTmp = raffleEntries[randomIndex];
            // Update the value at the random index to the current value
            raffleEntries[randomIndex] = raffleEntries[i];
            // Update the current value to the value at the random index
            raffleEntries[i] = randomTmp;
        }

        // Update number of shuffled entries
        shuffledCount += numShuffles;

        // Emit successful shuffle
        emit RaffleShuffled(msg.sender, numShuffles);
    }

    /// @notice Allows user to mint NFTs for winning tickets or claim refund for losing tickets
    /// @param tickets indices of all raffle tickets owned by caller
    function claimRaffle(uint256[] calldata tickets) external {
        // Ensure raffle has ended
        require(block.timestamp > RAFFLE_END_TIME, "Raffle has not ended");
        // Ensure raffle has been cleared
        require(
            // Either no shuffling required
            (raffleEntries.length < AVAILABLE_SUPPLY)
            // Or, shuffling completed
            || (shuffledCount == AVAILABLE_SUPPLY),
            "Raffle has not been cleared"
        );

        // Mint NFTs to winning tickets
        uint256 tmpCount = nftCount;
        for (uint256 i = 0; i < tickets.length; i++) {
            // Ensure ticket is in range
            require(tickets[i] < raffleEntries.length, "Ticket is out of entries range");
            // Ensure ticket has not already been claimed
            require(!ticketClaimed[tickets[i]], "Ticket already claimed");
            // Ensure ticket is owned by caller
            require(raffleEntries[tickets[i]] == msg.sender, "Ticket owner mismatch");

            // Toggle ticket claim status
            ticketClaimed[tickets[i]] = true;

            // If ticket is a winner
            if (tickets[i] + 1 <= AVAILABLE_SUPPLY) {
                // Mint NFT to caller
                _safeMint(msg.sender, nftCount + 1);
                // Increment number of minted NFTs
                nftCount++;
            }
        }
        // Calculate number of winning tickets from newly minted
        uint256 winningTickets = nftCount - tmpCount;

        // Refund losing tickets
        if (winningTickets != tickets.length) {
            // Payout value equal to number of bought tickets - paid for winning tickets
            (bool sent, ) = payable(msg.sender).call{
                value: (tickets.length - winningTickets) * MINT_COST
            }("");
            require(sent, "Unsuccessful in refund");
        }

        // Emit claim event
        emit RaffleClaimed(msg.sender, winningTickets, tickets.length - winningTickets);
    }

    /// @notice Sets entropy for clearing via shuffle
    function setClearingEntropy() external returns (bytes32 requestId) {
        // Ensure raffle has ended
        require(block.timestamp > RAFFLE_END_TIME, "Raffle still active");
        // Ensure contract has sufficient LINK balance
        require(LINK_TOKEN.balanceOf(address(this)) >= linkFee, "Insufficient LINK");
        // Ensure raffle requires entropy (entries !< supply)
        require(raffleEntries.length > AVAILABLE_SUPPLY, "Raffle does not need entropy");
        // Ensure raffle requires entropy (entropy not already set)
        require(!clearingEntropySet, "Clearing entropy already set");

        // Request randomness from Chainlink VRF
        return requestRandomness(KEY_HASH, linkFee);
    }

    /// @notice Reveals metadata for all NFTs with reveals pending (batch reveal)
    function revealPendingMetadata() external returns (bytes32 requestId) {
        // Ensure raffle has ended
        // Ensure at least 1 NFT has been minted
        // Ensure at least 1 minted NFT requires metadata
        require(nftCount - nftRevealedCount > 0, "No NFTs pending metadata reveal");
        // Ensure contract has sufficient LINK balance
        require(LINK_TOKEN.balanceOf(address(this)) >= linkFee, "Insufficient LINK");

        // Request randomness from Chainlink VRF
        return requestRandomness(KEY_HASH, linkFee);
    }

    /// @notice Fulfills randomness from Chainlink VRF
    /// @param requestId returned id of VRF request
    /// @param randomness random number from VRF
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        // If auction is cleared
        // Or, if auction does not need clearing
        if (clearingEntropySet || raffleEntries.length < AVAILABLE_SUPPLY) {
            // Push new metadata (end index non-inclusive)
            metadatas.push(Metadata({
                startIndex: nftRevealedCount + 1,
                endIndex: nftCount + 1,
                entropy: randomness
            }));
            // Update number of revealed NFTs
            nftRevealedCount = nftCount;
            return;
        }

        // Else, set entropy
        entropy = randomness;
        // Update entropy set status
        clearingEntropySet = true;
    }

    /// @notice Allows contract owner to withdraw proceeds of winning tickets
    function withdrawRaffleProceeds() external onlyOwner {
        // Ensure raffle has ended
        require(block.timestamp > RAFFLE_END_TIME, "Raffle has not ended");
        // Ensure proceeds have not already been claimed
        require(!proceedsClaimed, "Proceeds already claimed");

        // Toggle proceeds being claimed
        proceedsClaimed = true;

        // Calculate proceeds to disburse
        uint256 proceeds = MINT_COST * (
            raffleEntries.length > AVAILABLE_SUPPLY
                // Mint cost * available supply if many entries
                ? AVAILABLE_SUPPLY 
                // Else, mint cost * raffle entries
                : raffleEntries.length);

        // Pay owner proceeds
        (bool sent, ) = payable(msg.sender).call{value: proceeds}(""); 
        require(sent, "Unsuccessful in payout");

        // Emit successful proceeds claim
        emit RaffleProceedsClaimed(msg.sender, proceeds);
    }

    /// @notice Allows contract owner to change LINK fee paid to oracles
    function changeLinkFee(uint256 _linkFee) external onlyOwner {
        linkFee = _linkFee;
    }

    /// ============ Developer-defined functions ============

    /// @notice Returns metadata about a token (depending on randomness reveal status)
    /// @dev Partially implemented, returns only example string of randomness-dependent content
    function tokenURI(uint256 tokenId) override public view returns (string memory) {
        uint256 randomness;
        bool metadataCleared;
        string[3] memory parts;

        for (uint256 i = 0; i < metadatas.length; i++) {
            if (tokenId >= metadatas[i].startIndex && tokenId < metadatas[i].endIndex) {
                randomness = metadatas[i].entropy;
                metadataCleared = true;
                break;
            }
        }

        parts[0] = '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350"><style>.base { fill: white; font-family: serif; font-size: 14px; }</style><rect width="100%" height="100%" fill="black" /><text x="10" y="20" class="base">';

        if (metadataCleared) {
            parts[1] = string(abi.encodePacked('Randomness: ', _toString(randomness)));
        } else {
            parts[1] = 'No randomness assigned';
        }

        parts[2] = '</text></svg>';
        string memory output = string(abi.encodePacked(parts[0], parts[1], parts[2]));

        return output;
    }

    /// @notice Converts a uint256 to its string representation
    /// @dev Inspired by OraclizeAPI's implementation
    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
