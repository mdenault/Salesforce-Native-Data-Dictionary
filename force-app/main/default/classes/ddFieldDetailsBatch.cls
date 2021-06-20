public with sharing class ddFieldDetailsBatch implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts {

    private String objectDurableId;
    private String objectApiName;
    private String mode;

    public ddFieldDetailsBatch(String mode) {
        this.mode = mode;
    }

    private String getNextObject() {
        String s = '';

        return s;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query = '';
        if (this.mode == 'picklists-dependent') {
            query = 'SELECT Id, API_Name__c, Object__r.API_Name__c, Durable_ID__c FROM Data_Dictionary_Field__c WHERE Is_Dependant_Picklist__c = true AND Status__c = \'' + ddCoreService.FIELD_STATUS_ACTIVE + '\' ORDER BY API_Name__c';
        } else if (this.mode == 'picklists-recordtypes') {
            query = 'SELECT Id, API_Name__c, Object__r.API_Name__c, Durable_ID__c FROM Data_Dictionary_Field__c WHERE Data_Type__c = \'Picklist\' AND Status__c = \'' + ddCoreService.FIELD_STATUS_ACTIVE + '\' AND Object__r.Has_Record_Types__c = true ORDER BY API_Name__c';

        } else if (this.mode == 'field-permissions') {
            query = 'SELECT Id, API_Name__c, Object__r.API_Name__c, Durable_ID__c FROM Data_Dictionary_Field__c WHERE Data_Type__c = \'Picklist\' AND Status__c = \'' + ddCoreService.FIELD_STATUS_ACTIVE + '\' AND Object__r.Has_Record_Types__c = true ORDER BY API_Name__c';

        } else if (this.mode == 'dependencies') {
            query = 'SELECT Id, API_Name__c, Object__r.API_Name__c, Durable_ID__c FROM Data_Dictionary_Field__c WHERE Data_Type__c = \'Picklist\' AND Status__c = \'' + ddCoreService.FIELD_STATUS_ACTIVE + '\' AND Object__r.Has_Record_Types__c = true ORDER BY API_Name__c';
        } else {
            // Record counts
            query = 'SELECT Id, Data_Type__c, Data_Type_Details_Trunc__c, API_Name__c, Object__r.API_Name__c, Object__r.Has_Record_Types__c, Durable_ID__c, Usage_Count__c FROM Data_Dictionary_Field__c WHERE Status__c = \'' + ddCoreService.FIELD_STATUS_ACTIVE + '\' AND (Object__r.Type__c = \'' + ddCoreService.OBJECT_TYPE_STANDARDOBJECT + '\' OR Object__r.Type__c = \'' + ddCoreService.OBJECT_TYPE_CUSTOMOBJECT + '\') ORDER BY Name';
        }

        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<Data_Dictionary_Field__c> records) {
        ddFieldList fieldList = new ddFieldList(records);

        if (this.mode == 'recordcounts') {
            fieldList.setRecordCounts();
        }

        fieldList.Save();
    }

    public void finish(Database.BatchableContext bc) {


    }    

}
