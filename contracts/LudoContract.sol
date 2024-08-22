// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;


contract GameContract {
    struct Player {
        string playerId;
        uint wallet;
        address walletAddress;
        string name;
        string gameId;
        string photoUrl;
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
        string[] playerIds;
        uint256 lastModified;
        string admin;
        string media;
        bool isPublic;
        uint rTimeout;
        uint gameTime;
        string[] invPlayers;
    }
     struct GameInfo {
        string gameId;
        string gameType;
        uint minBet;
        bool autoHandStart;
        string media;
        bool isPublic;
        uint rTimeout;
        uint gameTime;
    }
    struct GameResponse {
        string gameId;
        string gameType;
        uint minBet;
        bool autoHandStart;
        Player[] players;
        uint256 lastModified;
        string admin;
        string media;
        bool isPublic;
        uint rTimeout;
        uint gameTime;
        string[] invPlayers;
    }

    mapping(string => Game) private games;
    mapping (string => Player) private players;
    string[] private gameIds;
    bool private locked;
    address private deployer;
    uint private commissionRate;
    uint private commission;

   
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

    modifier nonReentrant() {
        require(!locked, "ReentrancyGuard: reentrant call");
        locked = true;
        _;
        locked = false;
    }

     constructor() {
        deployer = msg.sender;
        commissionRate = 1;
    }

    /*********************************************************************
    ****************** Global FUNCTIONS *********************************
    **********************************************************************/

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
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

    /*********************************************************************
    ****************** HELPER FUNCTIONS *********************************
    **********************************************************************/

    function removeGameId(string calldata gameId) internal {
        for (uint i = 0; i < gameIds.length; i++) {
            if (keccak256(bytes(gameIds[i])) == keccak256(bytes(gameId))) {
                gameIds[i] = gameIds[gameIds.length - 1];
                gameIds.pop();
                break;
            }
        }
    }

    function removePlayerId(Game storage game, string calldata playerId) internal {
        for (uint i = 0; i < game.playerIds.length; i++) {
            if (keccak256(bytes(game.playerIds[i])) == keccak256(bytes(playerId))) {
                game.playerIds[i] = game.playerIds[game.playerIds.length - 1];
                game.playerIds.pop();
                break;
            }
        }
    }

    function handleInvPlayers(string[] calldata _invPlayers, Game storage game) internal {
        for (uint i = 0; i < _invPlayers.length; i++) {
            game.invPlayers.push(_invPlayers[i]);
        }
    }

    /*********************************************************************
    ****************** PLAYERS FUNCTIONS *********************************
    **********************************************************************/
    function addPlayer(Player memory _player) private {
        Player storage player = players[_player.playerId];
        player.gameId = _player.gameId;
        player.name = _player.name;
        player.wallet = _player.wallet;
        player.walletAddress = _player.walletAddress;
        player.playerId = _player.playerId;
        player.photoUrl = _player.photoUrl;
    }

    function updatePlayerWallet(string memory _playerId, uint _wallet) private {
        players[_playerId].wallet = _wallet;
    }

    function removePlayer(string calldata _playerId) private {
        isPlayerExists(_playerId);
        delete players[_playerId];
    }

    function getPlayer(string memory _playerId) private view returns (Player memory) {
        return isPlayerExists(_playerId);
    }

    function isPlayerJoined(string calldata _playerId) public view returns(string memory) {
        Player storage player = players[_playerId];
        return bytes(player.gameId).length > 0 ? player.gameId : "";
    }

    function isPlayerExists(string memory _playerId) private view returns(Player storage){
        require(bytes(players[_playerId].playerId).length >0, "Player does not exist");
        return players[_playerId];
    }


    /*********************************************************************
    ****************** Game FUNCTIONS *********************************
    **********************************************************************/

   function createGame(GameInfo calldata _game, Player calldata _player, string[] calldata _invPlayers) public payable nonReentrant  {
        require(bytes(isPlayerJoined(_player.playerId)).length == 0, "Player already joined in an active game");
        require(msg.value >= _game.minBet, "Insufficient buy-in amount");

        // Initialize the new game
        Game storage newGame = games[_game.gameId];
        newGame.gameId = _game.gameId;
        newGame.gameType = _game.gameType;
        newGame.minBet = _game.minBet;
        newGame.lastModified = block.timestamp;
        newGame.isPublic = _game.isPublic;
        newGame.media = _game.media;
        newGame.rTimeout = _game.rTimeout;
        newGame.autoHandStart = _game.autoHandStart;
        newGame.admin = _player.playerId;
        newGame.gameTime = _game.gameTime;
        
        // Handle _invPlayers in memory before updating storage
        handleInvPlayers(_invPlayers, newGame);

        // Initialize and add the player
        Player memory playerInfo = Player({
            playerId: _player.playerId,
            gameId: _game.gameId,
            wallet: msg.value,
            name: _player.name,
            walletAddress: _player.walletAddress,
            photoUrl: _player.photoUrl
        });

        addPlayer(playerInfo);

        // Add the game ID to the list of game IDs
        gameIds.push(_game.gameId);

        // Add the player ID to the list of player IDs
        newGame.playerIds.push(_player.playerId);

        // Emit the GameCreated event
        emit GameCreated(_game.gameId, _game.gameType);
    }
    
    // Function to add player in the game with the amount as their wallet
    function joinGame(string calldata _gameId, Player calldata _player) public payable nonReentrant {
        //check if gameId is valid
        require(bytes(_gameId).length > 0, "Invalid game ID");

         Game storage game = games[_gameId];
        //check if game is exist or not
        require(bytes(game.gameId).length > 0, "Game not found");

        // Check if the player is already in any active game
         string memory existingGameId = isPlayerJoined(_player.playerId);
        require(bytes(existingGameId).length == 0, "Player already joined in an active game");  

        //check if game is open seat or not
        require(game.playerIds.length <10, "No empty Seat");

        //check if valid deposit amount
        require(msg.value >= game.minBet, "Invalid deposit amount");

        // Initialize and add the player

         // Initialize and add the player
        Player memory playerInfo = Player({
            playerId: _player.playerId,
            gameId: _gameId,
            wallet: msg.value,
            name: _player.name,
            walletAddress: _player.walletAddress,
            photoUrl: _player.photoUrl
        });

        addPlayer(playerInfo);
       
        // Add the player ID to the list of player IDs
        game.playerIds.push(_player.playerId);
        game.lastModified = block.timestamp;

        emit PlayerJoined(_gameId, _player.playerId, msg.value);
    }

    // Function to remove a player from the game and transfer Matic to their wallet
    function leaveGame(string calldata gameId, PlayerCall[] calldata playersData, uint256 date) external payable onlyDeployer {
        Game storage game = games[gameId];
        require(bytes(game.gameId).length > 0, "Game not found");
        uint amt=0;
        for (uint i = 0; i < playersData.length; i++) {
            //check if player is in game
            Player memory player = getPlayer(playersData[i].playerId);

            address payable playerAddress = payable(player.walletAddress);
            if(player.wallet > uint256(playersData[i].wallet)){
                amt = player.wallet - uint256(playersData[i].wallet);
            }
            (bool sent, bytes memory data) = playerAddress.call{value: amt}("");
            require(sent, "Failed to send Ether");
            removePlayer(playersData[i].playerId);
            removePlayerId(game, playersData[i].playerId);

            if ((keccak256(abi.encodePacked(game.admin)) == keccak256(abi.encodePacked(playersData[i].playerId))) && game.playerIds.length >0 ) {
                game.admin = game.playerIds[0];
            }

            game.lastModified = date;
            emit PlayerLeft(game.gameId, playersData[i].playerId, data);
    
        }

        if (game.playerIds.length == 0) {
            delete games[gameId];
            removeGameId(gameId);
        }
    }

    // Function to update player wallets and deduct commission after finishing a hand
    function finishHand(string calldata gameId, PlayerCall [] calldata playersData, uint256 date) external onlyDeployer {
        Game storage game = games[gameId];
        require(bytes(game.gameId).length > 0, "Game not found");

        for (uint i = 0; i < playersData.length; i++) {
            //check if player is in game
            Player memory player = getPlayer(playersData[i].playerId);
            uint amt = 0;
            if (!playersData[i].isWon) {
                if(player.wallet > playersData[i].wallet){
                amt = player.wallet - playersData[i].wallet;
                }
            } else {
                uint commissionAmount = playersData[i].wallet * commissionRate / 100;
                commission += commissionAmount;
                amt = player.wallet + playersData[i].wallet - commissionAmount;
            }
           player.wallet = amt;
           updatePlayerWallet(player.playerId, amt);
        }
        game.lastModified = date;
    }

    function buyCoins(string calldata _gameId, string calldata _playerId, uint depositAmount, uint256 date) public payable nonReentrant {
        Game storage game = games[_gameId];
        require(bytes(game.gameId).length > 0, "Game not found");
        require(msg.value >= game.minBet, "Invalid deposit amount");
        Player memory player = getPlayer(_playerId);
        // Update the player's wallet with the depositAmount
        player.wallet += depositAmount;
        updatePlayerWallet(_playerId, player.wallet);
        game.lastModified = date;

        emit BuyCoin(_gameId, _playerId, depositAmount);
    }

    //getAllGame
    function getAllGames() public view returns (GameResponse[] memory) {
        GameResponse[]memory gameData = new GameResponse[](gameIds.length);

        for (uint i = 0; i < gameIds.length; i++) {
            gameData[i] = getGame(gameIds[i]);
        }
        return gameData;
    }

   //isGameExist
   function isGameExist(string memory _gameId) private view returns(Game memory) {
        require(bytes(games[_gameId].gameId).length > 0, "Game not found");
        return games[_gameId];
   }

   //getGame
    function getGame(string memory _gameId) public view returns(GameResponse memory){
        Game memory game = isGameExist(_gameId);
        GameResponse memory gameData = GameResponse({
            gameId: game.gameId,
            gameType: game.gameType,
            gameTime: game.gameTime,
            minBet: game.minBet,
            lastModified: game.lastModified,
            isPublic: game.isPublic,
            media: game.media,
            rTimeout: game.rTimeout,
            autoHandStart: game.autoHandStart,
            invPlayers: game.invPlayers,
            admin: game.admin,
            players: new Player[] (game.playerIds.length)
        });
        for(uint i=0; i<game.playerIds.length; i++){
            gameData.players[i] = getPlayer(game.playerIds[i]);
        }
        return gameData;
    }

}
