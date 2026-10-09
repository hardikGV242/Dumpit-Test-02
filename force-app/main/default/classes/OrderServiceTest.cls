@isTest
private class OrderServiceTest {
    @isTest static void testTotal() {
        System.assertEquals(20, OrderService.calcTotal(10, 2));
    }
}