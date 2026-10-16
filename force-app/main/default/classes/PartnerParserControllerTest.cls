@isTest
private class PartnerParserControllerTest {
    
    // Create a helper method to generate a standard test user
    private static User createTestUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        String uniqueName = 'partneruser' + DateTime.now().getTime() + '@test.com';
        User u = new User(
            Alias = 'ptest',
        Email='partneruser@test.com',
        EmailEncodingKey='UTF-8',
        LastName='Testing',
        LanguageLocaleKey='en_US',
        LocaleSidKey='en_US',
        ProfileId = p.Id,
        TimeZoneSidKey='America/Los_Angeles',
        UserName=uniqueName
            );
        insert u;
        
        // Assign the permission set to this new user safely
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Salesforce_Lead' LIMIT 1];
        insert new PermissionSetAssignment(
            AssigneeId = u.Id,
        PermissionSetId = ps.Id
            );
        
        return u;
    }
    
    @isTest
    static void testSavePartnersInsertAndUpsert() {
        // 1. Create and setup the user with permissions
        User testUser = createTestUser();
        
        // Fetch the Record Type ID for 'Partner'
        Id partnerRecordTypeId = Schema.SObjectType.Salesforce_Lead__c.getRecordTypeInfosByName().get('Partner').getRecordTypeId();
        
        Salesforce_Lead__c lead1 = new Salesforce_Lead__c(
            RecordTypeId = partnerRecordTypeId,
        Name = 'Test Partner 1',
        Listing_ID__c = 'EXT-001',
        Listing_URL__c = 'https://appexchange.salesforce.com/listingDetail?listingId=EXT-001',
        HQ_Location__c = 'New York, NY',
        Customer_Rating__c = 4.5,
        Customer_Reviews__c = 10,
        Recent_Projects__c = 5,
        Credentialed_People__c = 2
            );
        
        List<PartnerParserController.SaveResultWrapper> insertResults;
        List<PartnerParserController.SaveResultWrapper> upsertResults;
        
        // 2. Run the actual controller logic AS the permitted user
        System.runAs(testUser) {
            Test.startTest();
            insertResults = PartnerParserController.savePartners(new List<Salesforce_Lead__c>{ lead1 });
            Test.stopTest();
        }
        
        // 3. Assertions
        System.assertEquals(1, insertResults.size(), 'Should return one result wrapper.');
        System.assert(insertResults[0].isSuccess, 'Insert operation should succeed: ' + insertResults[0].message);
        
        List<Salesforce_Lead__c> savedRecords = [SELECT Id, Name, Listing_ID__c FROM Salesforce_Lead__c WHERE Listing_ID__c = 'EXT-001'];
        System.assertEquals(1, savedRecords.size(), 'One record should be created.');
        
        // Setup Upsert scenario
        lead1.Name = 'Updated Company Name';
        Salesforce_Lead__c lead2 = new Salesforce_Lead__c(
            RecordTypeId = partnerRecordTypeId,
        Name = 'Test Partner 2',
        Listing_ID__c = 'EXT-002',
        Listing_URL__c = 'https://appexchange.salesforce.com/listingDetail?listingId=EXT-002',
        HQ_Location__c = 'Austin, TX',
        Customer_Rating__c = 4.8,
        Customer_Reviews__c = 25,
        Recent_Projects__c = 12,
        Credentialed_People__c = 4
            );
        
        System.runAs(testUser) {
            upsertResults = PartnerParserController.savePartners(new List<Salesforce_Lead__c>{ lead1, lead2 });
        }
        
        System.assertEquals(2, upsertResults.size(), 'Should return two result wrappers.');
        System.assert(upsertResults[0].isSuccess, 'First record update should succeed.');
        System.assert(upsertResults[1].isSuccess, 'Second record insert should succeed.');
        System.assertEquals(2, [SELECT COUNT() FROM Salesforce_Lead__c], 'There should be exactly two records.');
    }
    
    @isTest
    static void testSavePartnersExceptionHandling() {
        User testUser = createTestUser();
        List<PartnerParserController.SaveResultWrapper> results;
        
        System.runAs(testUser) {
            Test.startTest();
            results = PartnerParserController.savePartners(null);
            Test.stopTest();
        }
        
        System.assert(results != null, 'Results should not be null.');
        System.assertEquals(0, results.size(), 'Results list should be empty for null input.');
    }
}