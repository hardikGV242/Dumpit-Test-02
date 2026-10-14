@IsTest
public class AppExchangeScraperTest {
    
    // 1. MOCK CLASS
    // Simulates the HTTP response from the AppExchange URL
    public class AppExchangeCalloutMock implements HttpCalloutMock {
        private Integer statusCode;
        private String body;
        
        public AppExchangeCalloutMock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }
        
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'text/html');
            res.setStatusCode(this.statusCode);
            res.setBody(this.body);
            return res;
        }
    }
    
    // Generates a fake HTML payload that matches the substring requirements in AppExchangeScraperService.cls
    private static String getMockHtmlBody() {
        return '<html><body>' +
            // Simulating the publisher JSON extraction
        '\"publisher\":{\"email\":\"test@mock.com\",\"website\":\"https://mock.com\",\"phoneNumber\":\"+18005550199\",\"yearFounded\":2015,\"employees\":25},\"extensions\"' +
        // Simulating the industry competencies extraction
        '\"industryCompetencies\":[\"Financial Services\",\"Healthcare\"],\"' +
            // Simulating the product competencies extraction
        '\"productCompetencies\":[\"Sales Cloud\",\"Service Cloud\"]}' +
            '</body></html>';
    }
    
    // 2. TEST DATA SETUP
    @TestSetup
    static void setupData() {
        Salesforce_Lead__c leadRec = new Salesforce_Lead__c(
            Listing_ID__c = 'a0b123456789',
        Name = 'Test SL 1',
        // Leaving Last_Sync__c blank to ensure it gets picked up by the Batch query
        Last_Sync__c = null
            );
        insert leadRec;
    }
    
    // 3. SERVICE CLASS TESTS (AppExchangeScraperService.cls)
    @IsTest
    static void testServiceSuccess() {
        Salesforce_Lead__c leadRec = [SELECT Id, Listing_ID__c FROM Salesforce_Lead__c LIMIT 1];
        
        // Set the mock callout with a 200 Success status code
        Test.setMock(HttpCalloutMock.class, new AppExchangeCalloutMock(200, getMockHtmlBody()));
        
        Test.startTest();
        // Call the service method
        Salesforce_Lead__c result = AppExchangeScraperService.fetchAndParse(leadRec);
        Test.stopTest();
        
        // Assertions to verify the JSON was parsed correctly
        Assert.areEqual('test@mock.com', result.Email__c, 'Email should match mock JSON.');
        Assert.areEqual('18005550199', result.Phone__c, 'Phone should have the "+" removed.');
        Assert.areEqual('2015', result.Founded__c, 'Founded year should be parsed as a string.');
        Assert.areEqual('21-100', result.Team_Size__c, 'Employees count of 25 should map to 21-100.');
        Assert.isTrue(result.Industry_Competencies__c.contains('Financial Services'), 'Industry list should be joined.');
    }
    
    @IsTest
    static void testServiceMissingListingId() {
        // Pass a record with no Listing ID
        Salesforce_Lead__c leadRec = new Salesforce_Lead__c();
        
        Test.startTest();
        try {
            AppExchangeScraperService.fetchAndParse(leadRec);
            Assert.fail('Expected a CalloutException for missing Listing ID.');
        } catch(Exception e) {
            Assert.isTrue(e.getMessage().contains('No Listing URL provided on the record.'), 'Correct exception message should be thrown.');
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testServiceHttpError() {
        Salesforce_Lead__c leadRec = [SELECT Id, Listing_ID__c FROM Salesforce_Lead__c LIMIT 1];
        
        // Set the mock callout to simulate a 404 Error
        Test.setMock(HttpCalloutMock.class, new AppExchangeCalloutMock(404, 'Not Found'));
        
        Test.startTest();
        try {
            AppExchangeScraperService.fetchAndParse(leadRec);
            Assert.fail('Expected a CalloutException for non-200 status.');
        } catch(Exception e) {
            Assert.isTrue(e.getMessage().contains('Failed to fetch AppExchange page.'), 'Exception should state failure.');
        }
        Test.stopTest();
    }
    
    // 4. BATCH CLASS TESTS (AppExchangeScraperBatch.cls)
    @IsTest
    static void testBatchExecution() {
        // Provide the successful mock for the batch job's callouts
        Test.setMock(HttpCalloutMock.class, new AppExchangeCalloutMock(200, getMockHtmlBody()));
        
        Test.startTest();
        AppExchangeScraperBatch batch = new AppExchangeScraperBatch();
        // Execute batch with a scope of 10 to simulate chunking
        Database.executeBatch(batch, 10);
        Test.stopTest();
        
        Salesforce_Lead__c result = [SELECT Last_Sync__c, Email__c FROM Salesforce_Lead__c LIMIT 1];
        
        // Assert that the Last_Sync__c field was updated by the batch execute method
        Assert.isNotNull(result.Last_Sync__c, 'Last_Sync__c should be populated with System.today().');
        Assert.areEqual('test@mock.com', result.Email__c, 'Record should be updated with parsed data.');
    }
    
    // 5. CONTROLLER TESTS (FetchLeadDetailsController.cls)
    @IsTest
    static void testControllerSuccess() {
        Salesforce_Lead__c leadRec = [SELECT Id FROM Salesforce_Lead__c LIMIT 1];
        
        // Provide the successful mock for the Aura controller's sync action
        Test.setMock(HttpCalloutMock.class, new AppExchangeCalloutMock(200, getMockHtmlBody()));
        
        Test.startTest();
        String resultMsg = FetchLeadDetailsController.syncLeadDetails(leadRec.Id);
        Test.stopTest();
        
        // Verify the success message
        Assert.areEqual('Successfully fetched and updated details from AppExchange.', resultMsg);
        
        // Verify database commit
        Salesforce_Lead__c updatedLead = [SELECT Email__c FROM Salesforce_Lead__c WHERE Id = :leadRec.Id];
        Assert.areEqual('test@mock.com', updatedLead.Email__c, 'Controller should have saved the enriched record.');
    }
    
    @IsTest
    static void testControllerException() {
        Test.startTest();
        try {
            // Pass an invalid ID to trigger the exception block
            FetchLeadDetailsController.syncLeadDetails('00Q000000000000');
            Assert.fail('Expected AuraHandledException to be thrown.');
        } catch (Exception e) {
            Assert.isTrue(e.getTypeName() == 'System.AuraHandledException', 'AuraHandledException should wrap standard errors.');
        }
        Test.stopTest();
    }
    
    // 6. SCHEDULER TESTS (AppExchangeScraperScheduler.cls)
    @IsTest
    static void testScheduler() {
        Test.startTest();
        // Define a CRON expression for midnight
        String cronExp = '0 0 0 * * ?';
        
        // Schedule the job
        String jobId = System.schedule('Test AppExchange Scraper Scheduler', cronExp, new AppExchangeScraperScheduler());
        Test.stopTest();
        
        // Assert that the job was successfully scheduled
        Assert.isNotNull(jobId, 'The scheduler job ID should not be null.');
    }
}