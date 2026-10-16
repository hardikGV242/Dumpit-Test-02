public class AppExchangeScraperScheduler implements Schedulable {
    
    public void execute(SchedulableContext sc) {
        AppExchangeScraperBatch scraperBatch = new AppExchangeScraperBatch();
        
        Database.executeBatch(scraperBatch, 50);
    }
}