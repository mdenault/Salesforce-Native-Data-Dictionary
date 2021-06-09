public with sharing class ddObjectProcessBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {

    private String apiName;

    public ddObjectProcessBatch(String apiName) {
        this.apiName = apiName;
    }

    public List<SObject> start(Database.BatchableContext bc) {
        if (String.isNotEmpty(this.apiName)) {
            return [SELECT Id, Durable_ID__c from Data_Dictionary_Object__c WHERE API_Name__c = :this.apiName LIMIT 1];
        } else {
            // TODO: exclude deleted items?
            return [SELECT Id, Durable_ID__c from Data_Dictionary_Object__c ORDER BY Name];
        }
    }

    public void execute(Database.BatchableContext bc, List<Data_Dictionary_Object__c> records) {
        for (Data_Dictionary_Object__c ddo : records) {
            // TODO: question, do we need two batch files, or can one loop handle both if we put object stuff here?
            // I don't think it will work because of the callouts
            // ddObjectService.processObjectByDDIds(ddo.Id, ddo.Durable_ID__c);

            ddObject ddoToProcess = new ddObject(ddo.Id, ddo.Durable_ID__c);
            ddoToProcess.Fill();
            ddoToProcess.Save();

            // ddFieldService.processObjectByDDIds(ddo.Id, ddo.Durable_ID__c);
        }
    }

    public void finish(Database.BatchableContext bc) {
        if (Test.isRunningTest() == false) {
            ddFieldProcessBatch ddfb = new ddFieldProcessBatch();
            Database.executeBatch(ddfb, 1);
        }
    }

}
