public with sharing class AppExchangeScraperService {
    
    // Can be called by UI Controller, Batch Jobs, or Queueables
    public static Salesforce_Lead__c fetchAndParse(Salesforce_Lead__c leadRec) {
        if (String.isBlank(leadRec.Listing_ID__c)) {
            throw new CalloutException('No Listing URL provided on the record.');
        }
        
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://appexchange.salesforce.com/appxListingDetail?listingId=' + leadRec.Listing_ID__c);
        req.setMethod('GET');
        req.setTimeout(60000); // 1-minute timeout for heavy pages
        
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
            return parseListingData(leadRec, res.getBody());
        } else {
            throw new CalloutException('Failed to fetch AppExchange page. Status code: ' + res.getStatusCode());
        }
    }
    
    @TestVisible
    private static Salesforce_Lead__c parseListingData(Salesforce_Lead__c leadRec, String htmlBody) {
        
        // 1. Extract the Publisher JSON payload
        // Included the colon in the search string so the payload starts cleanly with {
            String searchStart1 = '\"publisher\":';
            String searchEnd1 = '},\"extensions\"';
            
            String jsonPayload1 = htmlBody.substringBetween(searchStart1, searchEnd1);
            
            if (String.isNotBlank(jsonPayload1)) {
                jsonPayload1 += '}'; // Re-add the closing brace
                
                try {
                    Map<String, Object> publisher = (Map<String,Object>) JSON.deserializeUntyped(jsonPayload1);
                    
                    if(publisher.containsKey('email')) leadRec.Email__c = (String) publisher.get('email');
                    if(publisher.containsKey('website')) leadRec.Website__c = (String) publisher.get('website');
                    if(publisher.containsKey('phoneNumber')){
                        String phoneNumber = (String) publisher.get('phoneNumber');
                        leadRec.Phone__c = phoneNumber.remove('+');
                    }
                    
                    if(publisher.containsKey('yearFounded')) leadRec.Founded__c = String.valueOf(publisher.get('yearFounded'));
                    
                    // Handle Team Size Mapping
                    if (publisher.containsKey('employees')) {
                        Integer employees = (Integer) publisher.get('employees');
                        leadRec.Team_Size__c = mapTeamSize(employees);
                    }
                } catch (Exception e) {
                    System.debug('Error parsing AppExchange Publisher payload: ' + e.getMessage());
                }
            }
            
            // 2. Get Industry Competencies
            // Extract just the inner contents of the array and wrap it in brackets
            String searchStart2 = '\"industryCompetencies\":[';
            String searchEnd2 = '],\"';
            
            String jsonPayload2 = htmlBody.substringBetween(searchStart2, searchEnd2);
            
            if (String.isNotBlank(jsonPayload2)) {
                jsonPayload2 = '[' + jsonPayload2 + ']';
                
                try {
                    List<Object> indComps = (List<Object>) JSON.deserializeUntyped(jsonPayload2);
                    leadRec.Industry_Competencies__c = joinList(indComps);
                } catch (Exception e) {
                    System.debug('Error parsing AppExchange Industry payload: ' + e.getMessage());
                }
            }
            
            // 3. Get Product Competencies
            String searchStart3 = '\"productCompetencies\":[';
            String searchEnd3 = ']}';
            
            String jsonPayload3 = htmlBody.substringBetween(searchStart3, searchEnd3);
            
            if (String.isNotBlank(jsonPayload3)) {
                jsonPayload3 = '[' + jsonPayload3 + ']';
                
                try {
                    List<Object> prodComps = (List<Object>) JSON.deserializeUntyped(jsonPayload3);
                    leadRec.Product_Competencies__c = joinList(prodComps);
                } catch (Exception e) {
                    System.debug('Error parsing AppExchange Product payload: ' + e.getMessage());
                }
            }
            
            return leadRec;
        }
        
        private static String joinList(List<Object> objList) {
            if (objList == null || objList.isEmpty()) return '';
            List<String> strList = new List<String>();
            for (Object obj : objList) {
                strList.add((String) obj);
            }
            return String.join(strList, ',\n');
        }
        
        private static String mapTeamSize(Integer employees) {
            if (employees == null || employees == 0) return null; // 0 implies missing data on AppExchange
            if (employees <= 5) return '1-5';
            if (employees <= 20) return '6-20';
            if (employees <= 100) return '21-100';
            if (employees <= 200) return '101-200';
            if (employees <= 1000) return '201-1000';
            return '>1000';
        }
    }