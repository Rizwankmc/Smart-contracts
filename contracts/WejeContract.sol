/**
 *Submitted for verification at polygonscan.com on 2024-06-23
*/

/**
 *Submitted for verification at mumbai.polygonscan.com on 2024-03-02
*/

//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract GameContract {
    address public deployer;
    uint public commissionRate;
    uint public commission;
    

    struct Player {
        string playerId;
        uint wallet;
        address walletAddress;
        string photoUrl;
        string name;
    }

    struct PlayerCall {
        string playerId;
        uint wallet;
        address walletAddress;
        bool isWon;
    }

    

    struct Game {
        string gameId;
        string gameType;
        uint minBet;
        bool autoHandStart;
       Player [] players;
        uint256 lastModified;
        string admin;
        string media;
        bool isPublic;
        uint rTimeout;
    }

    mapping(string => Game) public games; // Change to hashmap
    string[] public gameIds; // Keep track of game IDs

    bool private locked;

    modifier nonReentrant() {
        require(!locked, "ReentrancyGuard: reentrant call");
        locked = true;
        _;
        locked = false;
    }

    event PlayerJoined(string gameId, string playerId, uint amount);
    event PlayerLeft(string gameId, string playerId, bytes data);
    event GameCreated(string gameId, string gameType);
    event BuyCoin(string gameId, string playerId, uint amount);
    event DeployerChanged(address oldDeployer, address newDeployer);
    event MaticTransferred(address recipient, uint amount, bytes data);

    modifier onlyDeployer() {
        require(msg.sender == deployer, "Only deployer can call this function");
        _;
    }

    constructor() {
        deployer = msg.sender;
        commissionRate = 1;
    }

     // Function to remove a gameId from the gameIds array
    function removeGameId(string memory gameId) private {
        for (uint i = 0; i < gameIds.length; i++) {
            if (keccak256(bytes(gameIds[i])) == keccak256(bytes(gameId))) {
                gameIds[i] = gameIds[gameIds.length - 1];
                gameIds.pop();
                break;
            }
        }
    }

     // Function to remove a gameId from the gameIds array
    function removePlayer(Game storage game, string memory playerId) private {
        for (uint i = 0; i < game.players.length; i++) {
            if (keccak256(bytes(game.players[i].playerId)) == keccak256(bytes(playerId))) {
                game.players[i] = game.players[game.players.length - 1];
                game.players.pop();
                break;
            }
        }
    }

    function findPlayerIndex(Game storage game, string memory playerId) internal view returns (int) {
        if (game.minBet >= 0) {
                for (uint i = 0; i < game.players.length; i++) {
                    if (keccak256(abi.encodePacked(game.players[i].playerId)) == keccak256(abi.encodePacked(playerId))) {
                        return int(i);
                    }
                }
            return  -1;
        }
        return -1; // Represents "not found"
    }

    // Function to check player is already joined or not
    function isPlayerJoined(string memory playerId) public view returns (string memory) {
    for (uint i = 0; i < gameIds.length; i++) {
        for (uint j = 0; j < games[gameIds[i]].players.length; j++) {
                    if (keccak256(abi.encodePacked(games[gameIds[i]].players[j].playerId)) == keccak256(abi.encodePacked(playerId))) {
                        return gameIds[i];
                    }
                }
    }
    return ""; // Player is not joined in any active game
    }

    //////////////////////////////////// ALL WRITE Functions ///////////////////////////////////////

    function createGame(string calldata gameId, string memory gameType, uint _minBet, Player calldata player, uint _rTimeout, string calldata _media, bool _isPublic, bool _autoHandStart) public payable nonReentrant  {
        require(msg.value >= _minBet, "Insufficient buy-in amount");
        bytes memory result = bytes(isPlayerJoined(player.playerId));
    require(result.length == 0, "Player already joined in an active game");
        Game storage newGame = games[gameId];
        newGame.gameId = gameId;
        newGame.gameType = gameType;
        newGame.minBet = _minBet;
        newGame.lastModified = block.timestamp;
        newGame.isPublic = _isPublic;
        newGame.media = _media;
        newGame.rTimeout = _rTimeout;
        newGame.admin = player.playerId;
        newGame.autoHandStart = _autoHandStart;
        gameIds.push(gameId);
         // Create a new Player struct and initialize it
        Player memory newPlayer;
        newPlayer.playerId = player.playerId;
        newPlayer.wallet = msg.value;
        newPlayer.walletAddress = player.walletAddress;
        newPlayer.name= player.name;
        newPlayer.photoUrl = player.photoUrl;
        newGame.players.push(newPlayer);
        emit GameCreated(gameId, gameType);
    }
    
    // Function to add player in the game with the amount as their wallet
    function joinGame(string memory gameId, Player calldata player) public payable nonReentrant {
        require(bytes(gameId).length > 0, "Invalid game ID");
        require(bytes(games[gameId].gameId).length > 0, "Game not found");
        require(games[gameId].players.length <10, "No empty Seat");
        require(msg.value >= games[gameId].minBet, "Invalid deposit amount");

        // Check if the player is already joined in any active game
        require(findPlayerIndex(games[gameId], player.playerId) == -1, "Player already joined in an active game");
    
        // Create a new Player struct and initialize it
        Player memory newPlayer;
        newPlayer.playerId = player.playerId;
        newPlayer.wallet = msg.value;
        newPlayer.walletAddress = player.walletAddress;
        newPlayer.name= player.name;
        newPlayer.photoUrl = player.photoUrl;
        games[gameId].players.push(newPlayer);
        games[gameId].lastModified = block.timestamp;

        emit PlayerJoined(gameId, player.playerId, msg.value);
    }

    // Function to remove a player from the game and transfer Matic to their wallet
    function leaveGame(string memory gameId, PlayerCall[] memory players, uint256 date) external payable onlyDeployer {
        Game storage game = games[gameId];
        require(bytes(game.gameId).length > 0, "Game not found");
        uint amt=0;
        for (uint i = 0; i < players.length; i++) {
            int playerIndex = findPlayerIndex(game, players[i].playerId);
        require(playerIndex != -1, "Player does not exist");

        address payable playerAddress = payable(game.players[uint(playerIndex)].walletAddress);
        if(game.players[uint(playerIndex)].wallet > uint256(players[i].wallet)){
        amt = game.players[uint(playerIndex)].wallet - uint256(players[i].wallet);
        }
        (bool sent, bytes memory data) = playerAddress.call{value: amt}("");
        require(sent, "Failed to send Ether");

        game.players[uint(playerIndex)] = game.players[game.players.length - 1];
        game.players.pop();

        if ((keccak256(abi.encodePacked(game.admin)) == keccak256(abi.encodePacked(players[i].playerId))) && game.players.length >0 ) {
            game.admin = game.players[0].playerId;
        }

        game.lastModified = date;
        emit PlayerLeft(game.gameId, players[i].playerId, data);
    
        }

        if (game.players.length == 0) {
             delete games[gameId];
            removeGameId(gameId);
        }
    }
    // Function to update player wallets and deduct commission after finishing a hand
    function finishHand(string memory gameId, PlayerCall [] memory players, uint256 date) external onlyDeployer {
        Game storage game = games[gameId];
        require(bytes(game.gameId).length > 0, "Game not found");

        for (uint i = 0; i < players.length; i++) {
             int playerIndex = findPlayerIndex(game, players[i].playerId);
        require(playerIndex != -1, "Player not found in the game");
        uint amt = 0;
        if (!players[i].isWon) {
            if(game.players[uint(playerIndex)].wallet > players[i].wallet){
            amt = game.players[uint(playerIndex)].wallet - players[i].wallet;
            }
        } else {
            uint commissionAmount = players[i].wallet * commissionRate / 100;
            commission += commissionAmount;
            amt = game.players[uint(playerIndex)].wallet + players[i].wallet - commissionAmount;
        }
        game.players[uint(playerIndex)].wallet = amt;
        }
        game.lastModified = date;
    }


       // Function for incrementing players wallet after buy coins
    function buyCoins(string memory gameId, string memory playerId, uint depositAmount, uint256 date) public payable nonReentrant {
        require(bytes(gameId).length > 0, "Invalid game ID");
        require(bytes(games[gameId].gameId).length > 0, "Game not found");
        require(msg.value >= games[gameId].minBet, "Invalid deposit amount");

        // Check if the player exists in the current game's players array
        int playerIndex = findPlayerIndex(games[gameId], playerId);

        require(playerIndex != -1, "Player does not exist");

        // Update the player's wallet with the depositAmount
        games[gameId].players[uint(playerIndex)].wallet += depositAmount;
        games[gameId].lastModified = date;

        emit BuyCoin(gameId, playerId, depositAmount);
    }

    // Function to change ownership of smart contract
    function changeDeployer(address newDeployer) external onlyDeployer {
        require(newDeployer != address(0), "Invalid deployer address");
        emit DeployerChanged(deployer, newDeployer);
        deployer = newDeployer;
    }
    
    // Function to transfer matic to recipient
    function transferMatic(address payable recipient, uint amount) external onlyDeployer {
        require(recipient != address(0), "Invalid recipient address");
        require(address(this).balance >= amount, "Insufficient balance");
        (bool sent, bytes memory data ) = recipient.call{value: amount}("");
        require(sent, "Failed to send Ether");
        emit MaticTransferred(recipient, amount, data);
    }

    function changeCommissionRate(uint rate) external onlyDeployer {
        require(rate > 0, "Commission rate must greater than 0");
        commissionRate = rate;
    }

    // Function to transfer matic to recipient
    function transferCommissionMatic(address payable recipient) external onlyDeployer {
        require(recipient != address(0), "Invalid recipient address");
        require(address(this).balance >= commission, "not enough commission to trasfer");
        (bool sent, bytes memory data ) = recipient.call{value: commission}("");
        require(sent, "Failed to send Ether");
        commission = 0;
        emit MaticTransferred(recipient, commission, data);
    }

    //////////////////////////// ALL READ Functions ////////////////////////////////////


    function getAllGames() public view returns (Game[] memory) {
    Game[]memory gameData = new Game[](gameIds.length);
    for (uint i = 0; i < gameIds.length; i++) {
        gameData[i] = games[gameIds[i]];
    }
    return gameData;
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getGameById(string memory gameId) public view returns (Game memory) {
        require(bytes(games[gameId].gameId).length > 0, "Game not Found");
        return games[gameId];
    }

}