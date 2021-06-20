public with sharing class ddFieldProcessBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {

    private String mode;
    // TODO: maybe durableID would be better, because there can be duplicats of an object API name
    private String objectApiName;

    public ddFieldProcessBatch() {
        this.objectApiName = null;
        this.mode = 'only-basics';
    }

    public ddFieldProcessBatch(String mode) {
        this.objectApiName = null;
        this.mode = mode;
    }

    public ddFieldProcessBatch(String apiName, String mode) {
        this.objectApiName = apiName;
        this.mode = mode;
    }

    public List<SObject> start(Database.BatchableContext bc) {
        if (String.isNotEmpty(this.objectApiName)) {
            return [
                SELECT Id, Durable_ID__c, API_Name__c
                FROM Data_Dictionary_Object__c
                WHERE API_Name__c = :this.objectApiName
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
            } else if (this.mode == 'all') {
                ddf.Fill();
            }

            ddf.Save();
        }
    }

    public void finish(Database.BatchableContext bc) {
        if (Test.isRunningTest() == false) {
            if (this.mode == 'only-basics') {
                ddFieldProcessBatch newBatch = new ddFieldProcessBatch(this.objectApiName , 'only-page-layouts');
                Database.executeBatch(newBatch, 1);
            } else if (this.mode == 'only-page-layouts') {
                ddFieldProcessBatch newBatch = new ddFieldProcessBatch(this.objectApiName, 'only-permissions');
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
