public with sharing class OrderService {
    public static Decimal calcTotal(Decimal price, Integer qty) {
        Decimal total = price * qty;
        return total;
    }
}