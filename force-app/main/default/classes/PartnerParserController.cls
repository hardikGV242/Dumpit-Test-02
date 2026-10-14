public with sharing class PartnerParserController {
    
    public class SaveResultWrapper {
        @AuraEnabled public String partnerName;
        @AuraEnabled public String listingId;
        @AuraEnabled public Boolean isSuccess;
        @AuraEnabled public String message;
    }
    
    @AuraEnabled
    public static List<SaveResultWrapper> savePartners(List<Salesforce_Lead__c> recordsToUpsert) {
        List<SaveResultWrapper> responseList = new List<SaveResultWrapper>();
        
        if (recordsToUpsert == null) {
            return responseList;
        }
        
        try {
            Schema.SObjectField externalIdField = Salesforce_Lead__c.Fields.Listing_ID__c;
            Database.UpsertResult[] results = Database.upsert(recordsToUpsert, externalIdField, false);
            
            for(Integer i = 0; i < results.size(); i++) {
                Database.UpsertResult res = results[i];
                Salesforce_Lead__c rec = recordsToUpsert[i];
                
                SaveResultWrapper srp = new SaveResultWrapper();
                srp.partnerName = rec.Name;
                srp.listingId = rec.Listing_ID__c;
                srp.isSuccess = res.isSuccess();
                
                if(res.isSuccess()) {
                    srp.message = 'Successfully saved.';
                } else {
                    String errMsgs = '';
                    for(Database.Error err : res.getErrors()) {
                        errMsgs += err.getMessage() + ' ';
                    }
                    srp.message = errMsgs.trim();
                }
                responseList.add(srp);
            }
        } catch (Exception e) {
            for(Salesforce_Lead__c rec : recordsToUpsert) {
                SaveResultWrapper srp = new SaveResultWrapper();
                srp.partnerName = rec.Name;
                srp.listingId = rec.Listing_ID__c;
                srp.isSuccess = false;
                srp.message = 'Exception: ' + e.getMessage();
                responseList.add(srp);
            }
        }
        return responseList;
    }
}