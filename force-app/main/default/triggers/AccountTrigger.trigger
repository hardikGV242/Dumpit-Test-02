trigger AccountTrigger on Account (before insert, before update) {
    for (Account a : Trigger.new) {
        if (a.AnnualRevenue != null) { a.Rating = AccountService.getTier(a.AnnualRevenue) == 'Gold' ? 'Hot' : 'Warm'; }
    }
}