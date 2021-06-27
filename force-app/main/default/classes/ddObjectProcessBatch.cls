public with sharing class ddObjectProcessBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {

    // Setting a Durable ID will process just that object; otherwise all objects will be processed
    private String durableId;

    public ddObjectProcessBatch(String durableId) {
        this.durableId = durableId;
    }

    public ddObjectProcessBatch() {
        this.durableId = null;
    }

    public List<SObject> start(Database.BatchableContext bc) {
        if (String.isNotEmpty(this.durableId)) {
            return [
                SELECT Id, Durable_ID__c
                FROM Data_Dictionary_Object__c
                WHERE Durable_ID__c = :this.durableId
                LIMIT 1];
        } else {
            return [
                SELECT Id, Durable_ID__c
                FROM Data_Dictionary_Object__c
                WHERE Status__c != :ddCoreService.OBJECT_STATUS_DELETED
                ORDER BY Name];
        }
    }

    public void execute(Database.BatchableContext bc, List<Data_Dictionary_Object__c> records) {
        for (Data_Dictionary_Object__c ddo : records) {
            ddObject ddoToProcess = new ddObject(ddo.Id, ddo.Durable_ID__c);
            ddoToProcess.fill();
            ddoToProcess.save();
        }
    }

    public void finish(Database.BatchableContext bc) {
        if (Test.isRunningTest() == false) {
            ddFieldProcessBatch ddfb = new ddFieldProcessBatch(this.durableId, 'only-basics');
            Database.executeBatch(ddfb, 1);
        }
    }

}
