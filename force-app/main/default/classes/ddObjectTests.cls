@IsTest
public with sharing class ddObjectTests {

    @TestSetup
    private static void setupData() {
        ddObjectProcess ddo = new ddObjectProcess();
        ddo.execute();
    }

    @IsTest
    public static void testBatchCustomObject() {
        List<Data_Dictionary_Object__c> ddos = [SELECT Id, Durable_ID__c FROM Data_Dictionary_Object__c WHERE API_Name__c = 'Data_Dictionary_Field__c'];

        Test.setMock(HttpCalloutMock.class, new ddHttpMockResponse('object', ddos[0].Durable_ID__c));

        Test.startTest();
        ddObjectProcessBatch ddob = new ddObjectProcessBatch(ddos[0].Durable_ID__c);
        Database.executeBatch(ddob, 1);
        Test.stopTest();

        // Assertions
        ddos = [SELECT Id, Durable_ID__c, Type__c, Status__c FROM Data_Dictionary_Object__c WHERE API_Name__c = 'Data_Dictionary_Field__c'];

        System.assertEquals(1, ddos.size());
        System.assertEquals(ddCoreService.OBJECT_TYPE_CUSTOMOBJECT, ddos[0].Type__c);
        System.assertEquals(ddCoreService.OBJECT_STATUS_ACTIVE, ddos[0].Status__c);

    }

    @IsTest
    public static void testBatchStandardObject() {

        List<Data_Dictionary_Object__c> ddos = [SELECT Id, Durable_ID__c FROM Data_Dictionary_Object__c WHERE API_Name__c = 'Contact'];

        Test.setMock(HttpCalloutMock.class, new ddHttpMockResponse('object', ddos[0].Durable_ID__c));

        Test.startTest();
        ddObjectProcessBatch ddob = new ddObjectProcessBatch(ddos[0].Durable_ID__c);
        Database.executeBatch(ddob, 1);
        Test.stopTest();

        // Assertions
        ddos = [SELECT Id, Durable_ID__c FROM Data_Dictionary_Object__c WHERE API_Name__c = 'Contact'];

        System.assertEquals(1, ddos.size(), '');
        System.assertEquals(ddCoreService.OBJECT_TYPE_STANDARDOBJECT, ddos[0].Type__c);
        System.assertEquals(ddCoreService.OBJECT_STATUS_ACTIVE, ddos[0].Status__c);
    }






    @IsTest
    public static void testBatchCustomObjectFieldBasics() {

        Data_Dictionary_Object__c ddo = [SELECT Id, Durable_ID__c FROM Data_Dictionary_Object__c WHERE API_Name__c = 'Data_Dictionary_Field__c' LIMIT 1];

        List<FieldDefinition> fieldDefinitions = [
            SELECT Id, DurableId, QualifiedApiName
            FROM FieldDefinition
            WHERE EntityDefinition.DurableId = :ddo.Durable_ID__c
            AND QualifiedApiName = 'API_Name__c'
        ];

        Test.setMock(HttpCalloutMock.class, new ddHttpMockResponse('object-fields', fieldDefinitions[0].DurableId));

        Test.startTest();
        ddFieldProcessBatch ddfp = new ddFieldProcessBatch(ddo.Durable_ID__c, 'only-basics');
        Database.executeBatch(ddfp, 1);
        Test.stopTest();

        // Assertions


    }

    @IsTest
    public static void testBatchCustomObjectFieldLayouts() {
        Test.setMock(HttpCalloutMock.class, new ddHttpMockResponse('object-fields', ''));

        Data_Dictionary_Object__c ddo = [SELECT Id, API_Name__c, Durable_ID__c FROM Data_Dictionary_Object__c WHERE API_Name__c = 'Data_Dictionary_Field__c' LIMIT 1];

        ddObjectFields ddf = new ddObjectFields();
        ddf.SetObjectId(ddo.Id);
        ddf.SetObjectDurableId(ddo.Durable_ID__c);
        ddf.SetObjectAPIName(ddo.API_Name__c);

        ddf.fillFromDDFs();
        ddf.fillFromFieldDefs();
        ddf.updateFieldMap();
        ddf.fillFromDescribe();

        Test.startTest();
        ddFieldProcessBatch ddfp = new ddFieldProcessBatch(ddo.Durable_ID__c, 'only-page-layouts');
        Database.executeBatch(ddfp, 1);
        Test.stopTest();

        // TODO: asserts!
    }

}
