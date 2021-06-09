@IsTest
public with sharing class ddObjectTests {

    @TestSetup
    private static void setupData() {
        ddObjectProcess ddo = new ddObjectProcess();
        ddo.execute();
    }

    @IsTest
    public static void testBatchCustomObject() {
        Test.setMock(HttpCalloutMock.class, new ddHttpMockResponse('object'));

        ddObjectProcessBatch ddob = new ddObjectProcessBatch('Data_Dictionary_Field__c');
        Database.executeBatch(ddob, 1);

    }

    @IsTest
    public static void testBatchStandardObject() {
        ddObjectProcessBatch ddob = new ddObjectProcessBatch('Contact');
        Database.executeBatch(ddob, 1);

    }


}
