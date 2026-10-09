@isTest
private class AccountServiceTest {
    @isTest static void testTier() {
        System.assertEquals('Gold', AccountService.getTier(2000000));
        System.assertEquals('Standard', AccountService.getTier(10));
        System.assertEquals('Unknown', AccountService.getTier(null));
    }
}