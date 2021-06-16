
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    // await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
            
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, {from: config.firstAirline});
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
      
  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false,{from: config.firstAirline});

      let reverted = false;
      try 
      {
          await config.flightSurety.setTestingMode(true, {from: config.firstAirline});
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");      

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true, {from:config.firstAirline});

  });

  it('(airline) is first airline registered', async () => {
    
   
    let result = await config.flightSuretyData.isAirline.call(config.firstAirline); 

    // ASSERT
    assert.equal(result, true, "Airline isnt registered");


  });

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    
    // ARRANGE
    let newAirline = accounts[2];
    let newAirline2 = accounts[3];

    let airlinename="Ethiopian";
    // ACT

    let reverted = false;
      try 
      {
        await config.flightSuretyApp.registerAirline(newAirline2, airlinename, {from: newAirline});
        
      }
      catch(e) {
          reverted = true;
      }
      let result2 = await config.flightSuretyData.isAirline.call(newAirline2); 


    // ASSERT
    assert.equal(result2, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });

  it('(airline) register an Airline using registerAirline() if it is funded', async () => {
    
    // ARRANGE
    let newAirline = accounts[2];
        let newAirline2 = accounts[3];

    let airlinename="Ethiopian";
    // ACT
    let reverted = true;
    try {
        await config.flightSuretyApp.fund.sendTransaction(config.firstAirline, {from: config.firstAirline, value: 10 }); 
        await config.flightSuretyApp.registerAirline.sendTransaction(newAirline2, airlinename, {from: config.firstAirline});

    }
    catch(e) {
      reverted= false;
    }
    let result = await config.flightSuretyApp.isFunded.call(config.firstAirline); 
    let result2 = await config.flightSuretyData.isAirline.call(newAirline2); 

    // ASSERT
    assert.equal(result, true, "Airline should be able to register another airline if it has provided funding");
    assert.equal(result2, true, "Reverted error");


  });

  it('(airline) Only existing airline may register a new airline', async () => {
    
    
    // ARRANGE
    let newAirline1 = accounts[2];
    let newAirline2 = accounts[3];
    let newAirline3 = accounts[4];
    let newAirline4 = accounts[5];
    let newAirline5 = accounts[6];

    let airlinename="Ethiopian";
    // ACT
    try {

        await config.flightSuretyApp.registerAirline.sendTransaction(newAirline4, airlinename, {from: newAirline5});

    }
    catch(e) {

    }
    let result4 = await config.flightSuretyData.isAirline.call(newAirline4); 
    assert.equal(result4, false, "Only existing airline may register a new airline5");

  });

  // 
 
  it('(Flights) Get List of Flights ', async () => {
    
    let revert=true;

    try {
        await config.flightSuretyApp.registerFlight('ET', 1625893909, config.firstAirline)}
    catch(e) {
        revert = false;
    }
    
    assert.equal(revert, true, "Flight registration error");

  });





















  // it('(airline) Only existing airline may register a new airline until there are at least four airlines registered', async () => {
    
    //   // ARRANGE
    //   let newAirline1 = accounts[2];
    //   let newAirline2 = accounts[3];
    //   let newAirline3 = accounts[9];
    //   let newAirline4 = accounts[5];
    //   let newAirline5 = accounts[6];
  
    //   let airlinename="Ethiopian";
    //   // ACT
    //   try {
  
    //       await config.flightSuretyApp.registerAirline.sendTransaction(newAirline1, airlinename, {from: config.firstAirline})
    //       await config.flightSuretyApp.registerAirline.sendTransaction(newAirline2, airlinename, {from: config.firstAirline});
    //       await config.flightSuretyApp.registerAirline.sendTransaction(newAirline3, airlinename, {from: config.firstAirline});
    //       await config.flightSuretyApp.registerAirline.sendTransaction(newAirline4, airlinename, {from: config.firstAirline});
    //       await config.flightSuretyApp.registerAirline.sendTransaction(newAirline5, airlinename, {from: config.firstAirline});
  
    //   }
    //   catch(e) {
  
    //   }
    //   let result1 = await config.flightSuretyData.isAirline.call(newAirline1); 
    //   let result2 = await config.flightSuretyData.isAirline.call(newAirline2); 
    //   let result3 = await config.flightSuretyData.isAirline.call(newAirline3); 
    //   let result4 = await config.flightSuretyData.isAirline.call(newAirline4); 
    //   let result5 = await config.flightSuretyData.isAirline.call(newAirline5); 
  
    //   // ASSERT
    //   // assert.equal(result, true, "Only existing airline may register a new airline1");
  
    //   assert.equal(result1, true, "Only existing airline may register a new airline1");
    //   assert.equal(result2, true, "Only existing airline may register a new airline2");
    //   assert.equal(result3, true, "Only existing airline may register a new airline3");
    //   assert.equal(result4, true, "Only existing airline may register a new airline4");
    //   assert.equal(result5, false, "Only existing airline may register a new airline5");
  
    // });
 

});
