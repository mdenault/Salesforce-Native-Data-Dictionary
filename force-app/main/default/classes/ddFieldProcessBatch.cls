public with sharing class ddFieldProcessBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id, Durable_ID__c, API_Name__c FROM Data_Dictionary_Object__c ORDER BY Name';
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<Data_Dictionary_Object__c> records) {
        for (Data_Dictionary_Object__c ddo : records) {
            // ddFieldService.processObjectByDDIds(ddo.Id, ddo.Durable_ID__c);
            ddObjectFields ddf = new ddObjectFields();
            ddf.SetObjectId(ddo.Id);
            ddf.SetObjectDurableId(ddo.Durable_ID__c);
            ddf.SetObjectAPIName(ddo.API_Name__c);
            ddf.Fill();
            ddf.Save();
        }
    }

    public void finish(Database.BatchableContext bc) {
        // TODO: determine if we fire off this batch, and the appropriate batch size, based on metadata
        //ddFieldDetailsBatch ddfb = new ddFieldDetailsBatch();
        //Database.executeBatch(ddfb, 10);
    }

}
