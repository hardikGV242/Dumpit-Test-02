public with sharing class FetchLeadDetailsController {
    @AuraEnabled
    public static String syncLeadDetails(Id recordId) {
        try {
            Salesforce_Lead__c leadRec = [
                SELECT Id, Listing_ID__c, Email__c, Founded__c, Industry_Competencies__c, 
                       Product_Competencies__c, Team_Size__c, Website__c 
                FROM Salesforce_Lead__c 
                WHERE Id = :recordId 
                LIMIT 1
            ];
            
            // Pass to the modular service
            leadRec = AppExchangeScraperService.fetchAndParse(leadRec);
            
            // Commit changes to database
            update leadRec;
            
            return 'Successfully fetched and updated details from AppExchange.';
            
        } catch (Exception e) {
            throw new AuraHandledException('Sync Failed: ' + e.getMessage());
        }
    }
}