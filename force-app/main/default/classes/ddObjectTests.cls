@IsTest
public with sharing class ddObjectTests {

    @IsTest
    public static void testBatchStandardObject() {
        ddObjectProcess ddo = new ddObjectProcess();
        ddo.execute();

        List<Data_Dictionary_Object__c> ddos = [SELECT Id, Durable_ID__c FROM Data_Dictionary_Object__c WHERE API_Name__c = 'Contact'];

        Test.setMock(HttpCalloutMock.class, new ddHttpMockResponse('object', ddos[0].Durable_ID__c));

        Test.startTest();
        ddObjectProcessBatch ddob = new ddObjectProcessBatch(ddos[0].Durable_ID__c);
        Database.executeBatch(ddob, 1);
        Test.stopTest();

        // Assertions
        ddos = [SELECT Id, Durable_ID__c, Type__c, Status__c FROM Data_Dictionary_Object__c WHERE API_Name__c = 'Contact'];

        System.assertEquals(1, ddos.size());
        System.assertEquals(ddCoreService.OBJECT_TYPE_STANDARDOBJECT, ddos[0].Type__c);
        System.assertEquals(ddCoreService.OBJECT_STATUS_ACTIVE, ddos[0].Status__c);
    }

    @IsTest
    public static void testBatchCustomObject() {
        ddObjectProcess ddo = new ddObjectProcess();
        ddo.execute();

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
    public static void testSingleObjectFullBatch() {
        List<EntityDefinition> entityData = [
            SELECT DurableId, QualifiedApiName
            FROM EntityDefinition
            WHERE QualifiedApiName = 'Data_Dictionary_Setting__mdt'
        ];

        Data_Dictionary_Object__c ddo = new Data_Dictionary_Object__c();
        ddo.API_Name__c = 'Data_Dictionary_Setting__mdt';
        ddo.Name = 'Data Dictionary Setting';
        ddo.Status__c = ddCoreService.OBJECT_STATUS_STUB;
        // ddo.Type__c = ddCoreService.OBJECT_TYPE_CUSTOMMETADATA;
        ddo.Durable_ID__c = entityData[0].DurableId;

        insert ddo;

        Test.setMock(HttpCalloutMock.class, new ddHttpMockResponse('object', ddo.Durable_ID__c));

        Test.startTest();
        ddObjectProcessBatch ddob = new ddObjectProcessBatch();
        Database.executeBatch(ddob, 1);
        Test.stopTest();

        // Assertions
        List<Data_Dictionary_Object__c> ddos = [SELECT Id, Durable_ID__c, Type__c, Status__c FROM Data_Dictionary_Object__c WHERE API_Name__c = 'Data_Dictionary_Setting__mdt'];

        System.assertEquals(1, ddos.size());
        System.assertEquals(ddCoreService.OBJECT_TYPE_CUSTOMMETADATA, ddos[0].Type__c);
        System.assertEquals(ddCoreService.OBJECT_STATUS_ACTIVE, ddos[0].Status__c);
    }

    @IsTest
    public static void testDraftObject() {
        Data_Dictionary_Object__c ddo = new Data_Dictionary_Object__c();
        ddo.API_Name__c = 'Data_Dictionary_Object__c';
        ddo.Name = 'Data Dictionary Object';
        // ddo.Type__c = ddCoreService.OBJECT_TYPE_CUSTOMOBJECT;
        ddo.Status__c = ddCoreService.OBJECT_STATUS_DRAFT;

        insert ddo;

        ddObjectProcess ddop = new ddObjectProcess();
        ddop.execute();

        List<Data_Dictionary_Object__c> ddos = [SELECT Id, Durable_ID__c, Type__c, Status__c FROM Data_Dictionary_Object__c WHERE API_Name__c = 'Data_Dictionary_Object__c'];

        Test.setMock(HttpCalloutMock.class, new ddHttpMockResponse('object', ddos[0].Durable_ID__c));

        Test.startTest();
        ddObjectProcessBatch ddob = new ddObjectProcessBatch(ddos[0].Durable_ID__c);
        Database.executeBatch(ddob, 1);
        Test.stopTest();

        // Assertions
        ddos = [SELECT Id, Durable_ID__c, Type__c, Status__c FROM Data_Dictionary_Object__c WHERE API_Name__c = 'Data_Dictionary_Object__c'];

        System.assertEquals(1, ddos.size());
        System.assertEquals(ddCoreService.OBJECT_TYPE_CUSTOMOBJECT, ddos[0].Type__c);
        System.assertEquals(ddCoreService.OBJECT_STATUS_ACTIVE, ddos[0].Status__c);
    }


    @IsTest
    public static void testObjectChangeLogCreation() {
        ddObjectProcess ddop = new ddObjectProcess();
        ddop.execute();

        List<Data_Dictionary_Object__c> ddos = [SELECT Id, Durable_ID__c FROM Data_Dictionary_Object__c WHERE API_Name__c = 'Data_Dictionary_Field__c'];

        Test.setMock(HttpCalloutMock.class, new ddHttpMockResponse('object', ddos[0].Durable_ID__c));

        Test.startTest();
        ddObjectProcessBatch ddob = new ddObjectProcessBatch(ddos[0].Durable_ID__c);
        Database.executeBatch(ddob, 1);
        Test.stopTest();

        ddos = [SELECT Id, Durable_ID__c, Type__c, Status__c FROM Data_Dictionary_Object__c WHERE API_Name__c = 'Data_Dictionary_Field__c'];

        Data_Dictionary_Object__c ddo = ddos[0];
        ddo.Description__c = 'New test description';
        update ddo;

        // Assertions
        List<Data_Dictionary_Change_Log__c> dcls = [SELECT Element__c, New_Value__c, Prior_Value__c FROM Data_Dictionary_Change_Log__c WHERE Object__c = :ddo.Id];
        System.assertEquals(1, dcls.size());
        System.assertEquals('Description', dcls[0].Element__c);
        System.assertEquals('New test description', dcls[0].New_Value__c);
    }
}
