@IsTest
public with sharing class ddObjectFieldTests {



    @IsTest
    public static void testBatchCustomObjectFieldBasics() {
        ddObjectProcess ddop = new ddObjectProcess();
        ddop.execute();

        Data_Dictionary_Object__c ddo = [SELECT Id, Durable_ID__c FROM Data_Dictionary_Object__c WHERE API_Name__c = 'Data_Dictionary_Field__c' LIMIT 1];

        List<FieldDefinition> fieldDefinitions = [
            SELECT Id, DurableId, QualifiedApiName
            FROM FieldDefinition
            WHERE EntityDefinition.DurableId = :ddo.Durable_ID__c
            AND QualifiedApiName = 'Description__c'
        ];

        Test.setMock(HttpCalloutMock.class, new ddHttpMockResponse('object-fields', fieldDefinitions[0].DurableId));

        Test.startTest();
        ddFieldProcessBatch ddfp = new ddFieldProcessBatch(ddo.Durable_ID__c, 'only-basics');
        Database.executeBatch(ddfp, 1);
        Test.stopTest();

        // Assertions


    }


    @IsTest
    public static void testBatchCustomObjectFieldActiveBasics() {
        List<EntityDefinition> entityData = [
            SELECT DurableId, QualifiedApiName
            FROM EntityDefinition
            WHERE QualifiedApiName = 'Data_Dictionary_Field__c'
        ];

        Data_Dictionary_Object__c ddo = new Data_Dictionary_Object__c();
        ddo.API_Name__c = 'Data_Dictionary_Field__c';
        ddo.Name = 'Data Dictionary Field';
        ddo.Status__c = ddCoreService.OBJECT_STATUS_ACTIVE;
        ddo.Type__c = ddCoreService.OBJECT_TYPE_CUSTOMOBJECT;
        ddo.Durable_ID__c = entityData[0].DurableId;

        insert ddo;

        List<FieldDefinition> fieldDefinitions = [
            SELECT Id, DurableId, QualifiedApiName
            FROM FieldDefinition
            WHERE EntityDefinition.DurableId = :ddo.Durable_ID__c
            AND QualifiedApiName = 'Description__c'
        ];

        Test.setMock(HttpCalloutMock.class, new ddHttpMockResponse('object-fields', fieldDefinitions[0].DurableId));

        /*
        ddObjectFields ddf = new ddObjectFields();
        ddf.setObjectId(ddo.Id);
        ddf.setObjectDurableId(ddo.Durable_ID__c);
        ddf.setObjectAPIName(ddo.API_Name__c);

        ddf.fillFromDDFs();
        ddf.fillFromFieldDefs();
        ddf.updateFieldMap();
        ddf.fillFromDescribe();
        ddf.fillCreateDates();
        ddf.fillOwnership();

        ddf.save();
        */

        Test.startTest();
        ddFieldProcessBatch ddfp = new ddFieldProcessBatch(ddo.Durable_ID__c, 'only-basics');
        Database.executeBatch(ddfp, 1);
        Test.stopTest();

        // TODO: asserts!
    }

    @IsTest
    public static void testBatchCustomObjectFieldLayouts() {
        List<EntityDefinition> entityData = [
            SELECT DurableId, QualifiedApiName
            FROM EntityDefinition
            WHERE QualifiedApiName = 'Data_Dictionary_Field__c'
        ];

        Data_Dictionary_Object__c ddo = new Data_Dictionary_Object__c();
        ddo.API_Name__c = 'Data_Dictionary_Field__c';
        ddo.Name = 'Data Dictionary Field';
        ddo.Status__c = ddCoreService.OBJECT_STATUS_ACTIVE;
        ddo.Type__c = ddCoreService.OBJECT_TYPE_CUSTOMOBJECT;
        ddo.Durable_ID__c = entityData[0].DurableId;

        insert ddo;

        List<FieldDefinition> fieldDefinitions = [
            SELECT Id, DurableId, QualifiedApiName
            FROM FieldDefinition
            WHERE EntityDefinition.DurableId = :ddo.Durable_ID__c
            AND QualifiedApiName = 'Description__c'
        ];

        Test.setMock(HttpCalloutMock.class, new ddHttpMockResponse('object-fields', fieldDefinitions[0].DurableId));

        ddObjectFields ddf = new ddObjectFields();
        ddf.setObjectId(ddo.Id);
        ddf.setObjectDurableId(ddo.Durable_ID__c);
        ddf.setObjectAPIName(ddo.API_Name__c);

        ddf.fillFromDDFs();
        ddf.fillFromFieldDefs();
        ddf.updateFieldMap();
        ddf.fillFromDescribe();
        ddf.save();

        Test.startTest();
        ddFieldProcessBatch ddfp = new ddFieldProcessBatch(ddo.Durable_ID__c, 'only-page-layouts');
        Database.executeBatch(ddfp, 1);
        Test.stopTest();

        // TODO: asserts!
    }

    @IsTest
    public static void testBatchCustomObjectFieldPerms() {
        List<EntityDefinition> entityData = [
            SELECT DurableId, QualifiedApiName
            FROM EntityDefinition
            WHERE QualifiedApiName = 'Data_Dictionary_Field__c'
        ];

        Data_Dictionary_Object__c ddo = new Data_Dictionary_Object__c();
        ddo.API_Name__c = 'Data_Dictionary_Field__c';
        ddo.Name = 'Data Dictionary Field';
        ddo.Status__c = ddCoreService.OBJECT_STATUS_ACTIVE;
        ddo.Type__c = ddCoreService.OBJECT_TYPE_CUSTOMOBJECT;
        ddo.Durable_ID__c = entityData[0].DurableId;

        insert ddo;

        List<FieldDefinition> fieldDefinitions = [
            SELECT Id, DurableId, QualifiedApiName
            FROM FieldDefinition
            WHERE EntityDefinition.DurableId = :ddo.Durable_ID__c
            AND QualifiedApiName = 'Description__c'
        ];

        Test.setMock(HttpCalloutMock.class, new ddHttpMockResponse('object-fields', fieldDefinitions[0].DurableId));

        ddObjectFields ddf = new ddObjectFields();
        ddf.setObjectId(ddo.Id);
        ddf.setObjectDurableId(ddo.Durable_ID__c);
        ddf.setObjectAPIName(ddo.API_Name__c);

        ddf.fillFromDDFs();
        ddf.fillFromFieldDefs();
        ddf.updateFieldMap();
        ddf.fillFromDescribe();
        ddf.save();

        List<Data_Dictionary_Field__c> fieldList = [SELECT Id FROM Data_Dictionary_Field__c where Object__c = :ddo.Id];
        System.debug(fieldList.size());

        Test.startTest();
        ddFieldProcessBatch ddfp = new ddFieldProcessBatch(ddo.Durable_ID__c, 'only-permissions');
        Database.executeBatch(ddfp, 1);
        Test.stopTest();

        // TODO: asserts!
    }

}
