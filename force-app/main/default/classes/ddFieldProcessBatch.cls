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
                SELECT Id, Durable_ID__c, API_Name__c, Status__c
                FROM Data_Dictionary_Object__c
                WHERE Durable_ID__c = :this.objectDurableId
                LIMIT 1];
        } else {
            return [
                SELECT Id, Durable_ID__c, API_Name__c, Status__c
                FROM Data_Dictionary_Object__c
                ORDER BY Name];
        }
    }

    public void execute(Database.BatchableContext bc, List<Data_Dictionary_Object__c> records) {
        for (Data_Dictionary_Object__c ddo : records) {
            System.debug('Starting processing of fields for ' + ddo.API_Name__c);
            System.debug('Status is ' + ddo.Status__c);
            System.debug('this.mode = ' + this.mode);

            ddObjectFields ddf = new ddObjectFields();
            ddf.setObjectId(ddo.Id);
            ddf.setObjectDurableId(ddo.Durable_ID__c);
            ddf.setObjectAPIName(ddo.API_Name__c);
            if (this.mode == 'only-basics') {
                ddf.fillFromDDFs();
                ddf.fillFromFieldDefs();
                ddf.updateFieldMap();
                if (ddo.Status__c == ddCoreService.OBJECT_STATUS_ACTIVE) {
                    ddf.fillFromDescribe();
                    ddf.fillCreateDates();
                    ddf.fillOwnership();
                }
            } else if (this.mode == 'only-page-layouts' && ddo.Status__c == ddCoreService.OBJECT_STATUS_ACTIVE) {
                ddf.fillFromDDFs();
                ddf.fillPageLayouts();
            } else if (this.mode == 'only-permissions' && ddo.Status__c == ddCoreService.OBJECT_STATUS_ACTIVE) {
                ddf.fillFromDDFs();
                ddf.fillPermissions();
            } else if (this.mode == 'only-dependent-picklists' && ddo.Status__c == ddCoreService.OBJECT_STATUS_ACTIVE) {
                ddf.fillFromDDFs();
                ddf.fillDependentPicklists();
            }

            ddf.save();
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
            } else if (this.mode == 'only-permissions') {
                ddFieldProcessBatch newBatch = new ddFieldProcessBatch(this.objectDurableId, 'only-dependent-picklists');
                Database.executeBatch(newBatch, 1);
            }

        }
    }

}
