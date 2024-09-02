/**
 *Submitted for verification at polygonscan.com on 2024-08-19
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SportsBetting {

    struct Match {
        uint gameId;
        bool isDrawable;
        uint homeId;
        uint awayId;
        string homeName;
        string awayName;
        string homeLogo;
        string awayLogo;
    }

    struct User {
        string uid;
        string name;
        string photoUrl;
        address walletAddress;
    }

    struct DistributionData {
        string uid;
        uint amount;
    }

    struct Selection {
        uint gameId;
        uint choice; // Enum for choices
    }

    struct Bet {
    uint amount;
    uint status;
    uint betId; // Consider bytes32 for efficiency
    uint pool;
    uint startDate; //first match start date
    uint endDate; // last match end date
    string[] userIds;
    Match[] matches;
    Selection[] results;
    mapping(string => UserWithSelections) userSelections;
}

    struct BetInfo {
        uint amount;
        uint betId;
        uint startDate;
        uint endDate;
    }

    struct UserWithSelections {
        string uid;
        string name;
        string photoUrl;
        address walletAddress;
        Selection[] selections;
    }

    struct BetSelectionDetails {
        uint amount;
        uint status;
        uint betId; // Consider bytes32 for efficiency
        uint pool;
        uint startDate; //first match start date
        uint endDate; // last match end date
        Match[] matches;
        Selection[] results;
        UserWithSelections[] userSelections;
    }

    mapping(uint => Bet) private bets; // Mapping of formId to Bet
    
    uint[] private betIds;
    uint private commission;
    bool private locked;
    address private deployer;
    uint private commissionRate;

    event BetOpened(uint betId, string desc);
    event BetJoined(uint betId, string desc);
    event BetRunning(uint betId, string desc);
    event BetFinished(uint betId, string desc);
    event BetDeleted(uint betId, string desc);

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
    
    // helper function
    function removeBetId(uint _betId) internal {
        for (uint i = 0; i < betIds.length; i++) {
            if (betIds[i] == _betId) {
                betIds[i] = betIds[betIds.length - 1];
                betIds.pop();
                break;
            }
        }
    }
    

    function openBet(BetInfo calldata _betInfo, Match[] calldata _matches, User calldata _openBy, Selection[] calldata _selections) public payable nonReentrant  {
        require(msg.value>= _betInfo.amount, "not enough Balance");
        Bet storage bet = bets[_betInfo.betId];
        bet.amount = msg.value;
        bet.betId = _betInfo.betId;
        bet.status = 0;
        bet.pool = msg.value;
        bet.startDate = _betInfo.startDate;
        bet.endDate = _betInfo.endDate;
        bet.userSelections[_openBy.uid].uid = _openBy.uid;
        bet.userSelections[_openBy.uid].name = _openBy.name;
        bet.userSelections[_openBy.uid].walletAddress = _openBy.walletAddress;
        bet.userSelections[_openBy.uid].photoUrl = _openBy.photoUrl;
        for (uint i = 0; i < _selections.length; i++) {
            bet.matches.push(_matches[i]);
            bet.userSelections[_openBy.uid].selections.push(Selection({
                gameId: _selections[i].gameId,
                choice: _selections[i].choice
            }));
        }
        bet.userIds.push(_openBy.uid);
        betIds.push(_betInfo.betId);
        emit BetOpened(_betInfo.betId, string(abi.encodePacked("Ticket is opened by ", _openBy.name)));
    }

    function joinBet(uint _betId, Selection[] calldata _selections, User calldata _user) public payable nonReentrant {
        Bet storage bet = bets[_betId];
        require(bet.betId >0, "Bet Ticket not found");
        require(bet.status == 0, "Bet is not open");
        require(msg.value == bet.amount, "Bet amount must match");

        bet.userSelections[_user.uid].uid = _user.uid;
        bet.userSelections[_user.uid].name = _user.name;
        bet.userSelections[_user.uid].walletAddress = _user.walletAddress;
        bet.userSelections[_user.uid].photoUrl = _user.photoUrl;
        for (uint i = 0; i < _selections.length; i++) {
            bet.userSelections[_user.uid].selections.push(Selection({
                gameId: _selections[i].gameId,
                choice: _selections[i].choice
            }));
        }
        bet.userIds.push(_user.uid);
        bets[_betId].pool += msg.value;

      emit BetJoined(_betId, string(abi.encodePacked("Ticket is opened by ", _user.name)));
    }

    function updateBetTicketStatus(uint _betId) external onlyDeployer  {
        Bet storage bet = bets[_betId];
        require(bet.betId >0, "Bet ticket not found");
        require(bet.status == 0, "Status already either running or finished");
        //check if only one user return money and delete ticket
        if(bet.userIds.length == 1) {
            UserWithSelections memory user = bet.userSelections[bet.userIds[0]];
             address payable playerAddress = payable(user.walletAddress);
            (bool sent,) = playerAddress.call{value: bets[_betId].amount}("");
            require(sent, "Failed to send Ether");
            delete bets[_betId];
            removeBetId(_betId);
           emit BetDeleted(_betId, "Only one user, ticket is deleted");
        }else {
            bets[_betId].status = 1;
            emit BetRunning(_betId, string(abi.encodePacked("Ticket status is running")));
        }
    }

    function distributeWinners(uint _betId, DistributionData[] calldata distributionData, Selection[] calldata _result) public onlyDeployer nonReentrant {
        Bet storage bet = bets[_betId];
        require(bet.betId > 0, "Bet ticket not found");

        for (uint i = 0; i < distributionData.length; i++) {
            UserWithSelections memory user = bet.userSelections[distributionData[i].uid];
            require(bytes(user.uid).length > 0, "User not found");
            //delete bets[_betId].userSelections[user.uid];
            address payable userAddress = payable(user.walletAddress);
            (bool sent, ) = userAddress.call{value: distributionData[i].amount}("");
            require(sent, "Failed to send Ether");
        }

        bet.status = 2;
        for (uint i = 0; i < _result.length; i++) {
            bet.results.push(_result[i]);
        }
        emit BetFinished(_betId, "Distribution done, Ticket removed");
    }

    function getTickets(uint _status) public view returns(BetSelectionDetails[] memory) {
        BetSelectionDetails[] memory tempTickets = new BetSelectionDetails[](betIds.length);
        uint count = 0;
        for (uint i = 0; i < betIds.length; i++) {
            if(bets[betIds[i]].status == _status){
               tempTickets[count] = getTicketByUserId(betIds[i]);
                count++;
            }
            
        }
         // Return a resized array with only the relevant tickets
        assembly {
            mstore(tempTickets, count)
        }
        return tempTickets;
    }




    function getTicketByUserId(uint _betId) public view returns (BetSelectionDetails memory) {
    Bet storage bet = bets[_betId];
    require(bet.betId > 0, "Ticket not found");

    BetSelectionDetails memory betDetail;
    betDetail.betId = _betId;
    betDetail.pool = bet.pool;
    betDetail.status = bet.status;
    betDetail.amount = bet.amount;
    betDetail.startDate = bet.startDate;
    betDetail.endDate = bet.endDate;
    betDetail.matches = bet.matches;

    UserWithSelections[] memory userWithSelection = new UserWithSelections[](bet.userIds.length);
    for (uint i = 0; i < bet.userIds.length; i++) {
        userWithSelection[i].uid = bet.userSelections[bet.userIds[i]].uid;
        userWithSelection[i].name = bet.userSelections[bet.userIds[i]].name;
        userWithSelection[i].photoUrl = bet.userSelections[bet.userIds[i]].photoUrl;
        userWithSelection[i].walletAddress = bet.userSelections[bet.userIds[i]].walletAddress;
        if (bet.userSelections[bet.userIds[i]].walletAddress == msg.sender || bet.status > 0) {
             userWithSelection[i].selections = bet.userSelections[bet.userIds[i]].selections;
        }else{
            userWithSelection[i].selections = new Selection[](0);
        }
       
    }
    betDetail.userSelections = userWithSelection;
    
    // check if match result is there return resul
    if(bet.status == 2){
    betDetail.results = bet.results;
    }

    return betDetail;
}


 function getTicketByIdWithSelections(uint _betId) public view onlyDeployer returns (BetSelectionDetails memory) {
    Bet storage bet = bets[_betId];
    require(bet.betId > 0, "Ticket not found");

    BetSelectionDetails memory betDetail;
    betDetail.betId = _betId;
    betDetail.pool = bet.pool;
    betDetail.status = bet.status;
    betDetail.amount = bet.amount;
    betDetail.startDate = bet.startDate;
    betDetail.endDate = bet.endDate;
    betDetail.matches = bet.matches;

    UserWithSelections[] memory userWithSelection = new UserWithSelections[](bet.userIds.length);
    for (uint i = 0; i < bet.userIds.length; i++) {
        userWithSelection[i].uid = bet.userSelections[bet.userIds[i]].uid;
        userWithSelection[i].name = bet.userSelections[bet.userIds[i]].name;
        userWithSelection[i].photoUrl = bet.userSelections[bet.userIds[i]].photoUrl;
        userWithSelection[i].walletAddress = bet.userSelections[bet.userIds[i]].walletAddress;
        userWithSelection[i].selections = bet.userSelections[bet.userIds[i]].selections;
    }
    betDetail.userSelections = userWithSelection;
    return betDetail;
}


     // Function to transfer matic to recipient
    function transferMatic(address payable recipient, uint amount) external onlyDeployer {
        require(recipient != address(0), "Invalid recipient address");
        require(address(this).balance >= amount, "Insufficient balance");
        (bool sent,) = recipient.call{value: amount}("");
        require(sent, "Failed to send Ether");
    }
}