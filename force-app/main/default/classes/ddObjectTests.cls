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

        Test.startTest();
        ddObjectProcessBatch ddob = new ddObjectProcessBatch('Data_Dictionary_Field__c');
        Database.executeBatch(ddob, 1);
        Test.stopTest();

        // TODO: asserts!
    }

    @IsTest
    public static void testBatchStandardObject() {
        Test.setMock(HttpCalloutMock.class, new ddHttpMockResponse('object'));

        Test.startTest();
        ddObjectProcessBatch ddob = new ddObjectProcessBatch('Contact');
        Database.executeBatch(ddob, 1);
        Test.stopTest();

        // TODO: asserts!
    }

    @IsTest
    public static void testBatchCustomObjectFields() {
        //Test.setMock(HttpCalloutMock.class, new ddHttpMockResponse('object'));

        Test.startTest();
        ddFieldProcessBatch ddfp = new ddFieldProcessBatch('Data_Dictionary_Field__c', 'only-basics');
        Database.executeBatch(ddfp, 1);
        Test.stopTest();

        // TODO: asserts!
    }

}
