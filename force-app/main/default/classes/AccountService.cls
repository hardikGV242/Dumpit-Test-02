public with sharing class AccountService {
    public static String getTier(Decimal revenue) {
        if (revenue == null) { return 'Unknown'; }
        if (revenue > 1000000) { return 'Gold'; }
        return 'Standard';
    }
}