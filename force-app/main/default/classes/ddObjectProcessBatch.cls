public with sharing class ddObjectProcessBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {

    // Setting an API Name will process just that object; otherwise all objects will be processed
    private String apiName;

    public ddObjectProcessBatch(String apiName) {
        this.apiName = apiName;
    }

    public ddObjectProcessBatch() {
        this.apiName = null;
    }

    public List<SObject> start(Database.BatchableContext bc) {
        if (String.isNotEmpty(this.apiName)) {
            return [
                SELECT Id, Durable_ID__c
                FROM Data_Dictionary_Object__c
                WHERE API_Name__c = :this.apiName
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
            ddoToProcess.Fill();
            ddoToProcess.Save();
        }
    }

    public void finish(Database.BatchableContext bc) {
        if (Test.isRunningTest() == false) {
            ddFieldProcessBatch ddfb = new ddFieldProcessBatch(this.apiName, 'only-basics');
            Database.executeBatch(ddfb, 1);
        }
    }

}
