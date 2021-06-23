public with sharing class ddFieldProcessBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {

    private String mode;
    private String objectDurableId;

    public ddFieldProcessBatch() {
        this.objectDurableId = null;
        this.mode = 'only-basics';
    }

    public ddFieldProcessBatch(String mode) {
        this.objectDurableId = null;
        this.mode = mode;
    }

    public ddFieldProcessBatch(String objectDurableId, String mode) {
        this.objectDurableId = objectDurableId;
        this.mode = mode;
    }

    public List<SObject> start(Database.BatchableContext bc) {
        if (String.isNotEmpty(this.objectDurableId)) {
            return [
                SELECT Id, Durable_ID__c, API_Name__c
                FROM Data_Dictionary_Object__c
                WHERE Durable_ID__c = :this.objectDurableId
                LIMIT 1];
        } else {
            return [
                SELECT Id, Durable_ID__c, API_Name__c
                FROM Data_Dictionary_Object__c
                ORDER BY Name];
        }
    }

    public void execute(Database.BatchableContext bc, List<Data_Dictionary_Object__c> records) {
        for (Data_Dictionary_Object__c ddo : records) {
            System.debug('Starting processing of fields for ' + ddo.API_Name__c);
            System.debug('this.mode = ' + this.mode);

            ddObjectFields ddf = new ddObjectFields();
            ddf.SetObjectId(ddo.Id);
            ddf.SetObjectDurableId(ddo.Durable_ID__c);
            ddf.SetObjectAPIName(ddo.API_Name__c);
            if (this.mode == 'only-basics') {
                ddf.fillFromDDFs();
                ddf.fillFromFieldDefs();
                ddf.updateFieldMap();
                ddf.fillFromDescribe();
                ddf.fillCreateDates();
                ddf.fillOwnership();
            } else if (this.mode == 'only-page-layouts') {
                ddf.fillFromDDFs();
                ddf.fillPageLayouts();
            } else if (this.mode == 'only-permissions') {
                ddf.fillFromDDFs();
                ddf.fillPermissions();
            }

            ddf.Save();
        }
    }

    public void finish(Database.BatchableContext bc) {
        if (Test.isRunningTest() == false) {
            if (this.mode == 'only-basics') {
                ddFieldProcessBatch newBatch = new ddFieldProcessBatch(this.objectDurableId , 'only-page-layouts');
                Database.executeBatch(newBatch, 1);
            } else if (this.mode == 'only-page-layouts') {
                ddFieldProcessBatch newBatch = new ddFieldProcessBatch(this.objectDurableId, 'only-permissions');
                Database.executeBatch(newBatch, 1);
            }

            // TODO: determine if we fire off this batch, and the appropriate batch size, based on metadata
            // } else {
            // ddFieldDetailsBatch ddfb = new ddFieldDetailsBatch();
            // Database.executeBatch(ddfb, 10);
            // }

        }
    }

}
