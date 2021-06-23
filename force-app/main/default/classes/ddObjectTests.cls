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

        // Assertions
        List<Data_Dictionary_Object__c> ddos = [SELECT Id, Durable_ID__c FROM Data_Dictionary_Object__c WHERE API_Name__c = 'Data_Dictionary_Field__c'];
        System.assertEquals(1, ddos.size());

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
    public static void testBatchCustomObjectFieldBasics() {
        Test.setMock(HttpCalloutMock.class, new ddHttpMockResponse('object-fields'));

        Data_Dictionary_Object__c ddo = [SELECT Id, Durable_ID__c FROM Data_Dictionary_Object__c WHERE API_Name__c = 'Data_Dictionary_Field__c' LIMIT 1];

        ddObject ddoToProcess = new ddObject(ddo.Id, ddo.Durable_ID__c);
        ddoToProcess.Fill();
        ddoToProcess.Save();

        Test.startTest();
        ddFieldProcessBatch ddfp = new ddFieldProcessBatch('Data_Dictionary_Field__c', 'only-basics');
        Database.executeBatch(ddfp, 1);
        Test.stopTest();

        // TODO: asserts!
    }

    @IsTest
    public static void testBatchCustomObjectFieldLayouts() {
        Test.setMock(HttpCalloutMock.class, new ddHttpMockResponse('object-fields'));

        ddObjectFields ddf = new ddObjectFields();
        ddf.SetObjectId(ddo.Id);
        ddf.SetObjectDurableId(ddo.Durable_ID__c);
        ddf.SetObjectAPIName(ddo.API_Name__c);

        ddf.fillFromDDFs();
        ddf.fillFromFieldDefs();
        ddf.updateFieldMap();
        ddf.fillFromDescribe();

        Test.startTest();
        ddFieldProcessBatch ddfp = new ddFieldProcessBatch('Data_Dictionary_Field__c', 'only-page-layouts');
        Database.executeBatch(ddfp, 1);
        Test.stopTest();

        // TODO: asserts!
    }

}
