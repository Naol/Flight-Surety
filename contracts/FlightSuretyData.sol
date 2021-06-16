pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false
    uint registrationFee = 10 ether;
    uint insuranceCap = 1 ether;
    uint256 private airlinesCounter=0;
    uint public flightCount;


    struct Airline {
        uint id;
        string airlineName;
        bool isFunded; 
        bool isRegistered;
    }

    struct Flight{
        uint id;
        string flight;
        bytes32 key;
        address airlineAddress;
        uint departureTimestamp;
        uint8 departureStatusCode;
        uint departureTimestampIfUpdated;
    }

    struct Insurance {
        address owner;
        bytes32 key;
        uint256 amount;
    }

    mapping(address => Airline) private airlines;
    mapping(address => uint256) private airlineFunds;
    mapping(address => bool) private noOfAirlinesReg;
    mapping(address => uint256) private credit;

    // address[] noOfAirlinesReg = new address[](0);
    mapping(bytes32 => uint) flightKeyToId;
	mapping(bytes32 => Flight) private flights;
    // mapping(address => amount) private paidAmount;
    // mapping(address => uint256) private insurances; 
    // Insurance[] private insurances;

    
	mapping(address => mapping(bytes32 => uint256)) private insurances;
	mapping(bytes32 => address[]) private flightInsurees;
	mapping(address => uint256) private travellerFunds;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    
    event AirlineRegistered(string name, bool isFunded, bool isRegistered);
    event FundedByAirline (address sender, uint256 rec);
    event FlightRegistered(uint flightCount);
    event InsuranceBought(address buyer, bytes32 flightKey, uint256 amount);

    event InsureeCreditted(bytes32 flightKey);
    event InsureePaid(address insuree, uint256 amount);
    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor() public 
    {
        contractOwner = msg.sender;
        airlinesCounter = airlinesCounter.add(1);
        airlines[contractOwner] = Airline({ id:airlinesCounter, airlineName: 'First', isFunded: true, isRegistered: true });

        noOfAirlinesReg[contractOwner] = true;


        emit AirlineRegistered(
            airlines[contractOwner].airlineName,
            airlines[contractOwner].isFunded,
            airlines[contractOwner].isRegistered
        );

    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier setCap(){
        require(msg.value > 1 ether, "Maximum Ether to purchase is 1 ether ");
        _;
    }

    modifier hasPaidEnough(uint requiredAmount)
    {
        require(msg.value >= requiredAmount, "The message value is less than required amount");
        _;
    }

    modifier returnChangeForExcessToSender(uint requiredAmount)
    {
        _;
        uint change = msg.value.sub(requiredAmount);
        msg.sender.transfer(change);
    }


    modifier verifyAirlineExists(address _address)
    {
        require(airlines[_address].id >0, "Airline with given address does not exists");
        _;
    }
    modifier verifyNotDepartedAlready(uint _timestamp){
        require(_timestamp > block.timestamp, "Flight has been departed already, so it makes no sense to sell insurances for it.");
        _;
    }

    modifier hasProvidedFunding(){
        require(airlines[msg.sender].isFunded,"Please provide funding");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            requireContractOwner 
    {
        operational = mode;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline(address adrs, string name) external 
        requireIsOperational returns(bool)
    {
        require(!airlines[adrs].isRegistered, "Airline is already registered");
        airlinesCounter = airlinesCounter.add(1);

        airlines[adrs] = Airline({ id:airlinesCounter, airlineName: name, isFunded: false, isRegistered: true });

        noOfAirlinesReg[adrs] = true;
        emit AirlineRegistered(
            airlines[adrs].airlineName,
            airlines[adrs].isFunded,
            airlines[adrs].isRegistered
        );

        
        return true;
    }

    function getAirlinesLength() external view returns(uint256) {
        return airlinesCounter;
    }

    function getAirline (address adrs) public view
    returns (string airlineName, bool isFunded, bool isRegistered)
    {
        require(noOfAirlinesReg[adrs], "Airline Doesnt exist");
        airlineName = airlines[adrs].airlineName;
        isFunded = airlines[adrs].isFunded;
        isRegistered = airlines[adrs].isRegistered;
    }

    function isAirline(address adrs) public view returns (bool) {
        return airlines[adrs].isRegistered;
    }

   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy(address airline, string flight, uint256 timestamp, address passenger) external payable requireIsOperational {
		bytes32 flightKey = getFlightKey(airline, flight, timestamp);
		insurances[passenger][flightKey] = insurances[passenger][flightKey].add(msg.value);
		flightInsurees[flightKey].push(passenger);
	}


    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees(address airline, string flight, uint256 timestamp, uint8 creditNumerator, uint8 creditDenominator) external requireIsOperational {
		bytes32 flightKey = getFlightKey(airline, flight, timestamp);

		for (uint i = 0; i < flightInsurees[flightKey].length; i++) {
			address passenger = flightInsurees[flightKey][i];
			uint256 insuranceAmount = insurances[passenger][flightKey];

			// Calcule the amount the insuree must be credited
			uint256 amountToPay = insuranceAmount.mul(creditNumerator).div(creditDenominator);
			// add funds to the passenger that subscribed an insurance
			travellerFunds[flightInsurees[flightKey][i]] = travellerFunds[flightInsurees[flightKey][i]].add(amountToPay);

			// emit BalanceChanged(passenger);

			// set the amount of the insurance to 0 for this passenger
			insurances[passenger][flightKey] = 0;
		}

		// Delete the array that list all the passenger that took an insurance for the flight
		delete flightInsurees[flightKey];
	}


    function isFunded(address adrs) external view returns(bool){
        return airlines[adrs].isFunded;
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
	function pay(address traveller) external requireIsOperational {
		require(travellerFunds[traveller] > 0, "This traveller has no funds");
		uint256 toPay = travellerFunds[traveller];
		delete travellerFunds[traveller];
		traveller.transfer(toPay);
	}

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund(address sender) public payable requireIsOperational
    {
        // require(msg.value == 10 ether, "The fund must be 10 ether");
        // require(
        //     airlines[msg.sender].isFunded == false,
        //     "The airline has already funded"
        // );


        uint256 existingAmount = airlineFunds[sender];
        uint256 totalAmount = existingAmount.add(msg.value);
        airlineFunds[sender] = 0;
        sender.transfer(msg.value); 

        airlines[sender].isFunded = true;
        airlineFunds[sender] = totalAmount;

        emit FundedByAirline(sender, msg.value);
    }


    function registerFlight (string _flight, uint _departureTimestamp, address _airlineAddress)
    requireIsOperational
    verifyAirlineExists(_airlineAddress)
    verifyNotDepartedAlready(_departureTimestamp)
    external
    {
        flightCount = flightCount.add(1);
        bytes32 key = getFlightKey(_airlineAddress, _flight, _departureTimestamp);
        flights[key] = Flight(
            {id: flightCount,
            flight: _flight,
            key: key,
            airlineAddress: _airlineAddress,
            departureTimestamp: _departureTimestamp,
            departureStatusCode: 0,
            departureTimestampIfUpdated: block.timestamp});
        // flightKeyToId[key] = flightCount;

        emit FlightRegistered(flightCount);
    }

    function getFlight(bytes32 key) external returns(bytes32 flight){
        return flights[key].key;
    }

    function getFlightKey
                        (
                            address airline,
                            string flight,
                            uint256 timestamp
                        )
                        pure
                        public
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() external payable 
    {
        fund(msg.sender);
    }


}

