public class AppExchangeScraperBatch implements Database.Batchable<sObject>, Database.AllowsCallouts {
    
    // 1. Query the records you want to process
    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id, Listing_ID__c, Email__c, Website__c, Phone__c,Founded__c, Team_Size__c, Industry_Competencies__c, Product_Competencies__c, Last_Sync__c ' +
            'FROM Salesforce_Lead__c ' +
            'WHERE Last_Sync__c = NULL  OR Last_Sync__c < Last_n_Days:3';
        return Database.getQueryLocator(query);
    }
    
    // 2. Process the records in chunks (scope)
    public void execute(Database.BatchableContext bc, List<Salesforce_Lead__c> scope) {
        List<Salesforce_Lead__c> leadsToUpdate = new List<Salesforce_Lead__c>();
        
        for (Salesforce_Lead__c leadRec : scope) {
            try {
                Salesforce_Lead__c updatedLead = AppExchangeScraperService.fetchAndParse(leadRec);
                
                updatedLead.Last_Sync__c = System.today();
                
                leadsToUpdate.add(updatedLead);
                
            } catch (Exception e) {
                System.debug('Failed to process Lead ID ' + leadRec.Id + ': ' + e.getMessage());
            }
        }
        
        // 3. Perform a bulk update for the successful records
        if (!leadsToUpdate.isEmpty()) {
            Database.update(leadsToUpdate, false);
        }
    }
    
    // 4. Wrap up (optional logging or email notifications)
    public void finish(Database.BatchableContext bc) {
        System.debug('AppExchange Scraper Batch Finished.');
    }
}