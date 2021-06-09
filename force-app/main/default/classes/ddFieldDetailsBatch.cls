public with sharing class ddFieldDetailsBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id, Data_Type__c, Data_Type_Details_Trunc__c, API_Name__c, Object__r.API_Name__c, Object__r.Has_Record_Types__c, Durable_ID__c, Usage_Count__c FROM Data_Dictionary_Field__c WHERE Status__c = \'' + ddCoreService.FIELD_STATUS_ACTIVE + '\' AND (Object__r.Type__c = \'' + ddCoreService.OBJECT_TYPE_STANDARDOBJECT + '\' OR Object__r.Type__c = \'' + ddCoreService.OBJECT_TYPE_CUSTOMOBJECT + '\') ORDER BY Name';
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<Data_Dictionary_Field__c> records) {
        for (Data_Dictionary_Field__c ddf : records) {
            // Calculate overall usage

            Integer totalUsage = null;
            Map<Id, Integer> usageMapById = new Map<Id, Integer>();

            if (ddf.Object__r.Has_Record_Types__c) {
                if (ddCoreService.FIELD_TYPES_COUNTABLE.contains(ddf.Data_Type__c) && ddCoreService.FIELD_TRUNCTYPES_PSEUDOCOUNTABLE.contains(ddf.Data_Type_Details_Trunc__c) == false) {
                    totalUsage = 0;
                    try {
                        List<AggregateResult> groupedResults = Database.query('SELECT RecordTypeId, Count(' + ddf.API_Name__c + ') FROM ' + ddf.Object__r.API_Name__c + ' GROUP BY RecordTypeId');

                        for (AggregateResult ar : groupedResults) {
                            usageMapById.put((Id)ar.get('RecordTypeId'), (Integer)ar.get('expr0'));
                            totalUsage = totalUsage + (Integer)ar.get('expr0');
                        }
                    } catch (Exception ex) {
                        System.debug('Error in record type COUNT(fieldName) query for field ' + ddf.API_Name__c);
                        throw ex;
                    }
                } else {
                    totalUsage = 0;
                }
            } else {
                if (ddf.API_Name__c != 'Id' && (ddCoreService.FIELD_TYPES_COUNTABLE.contains(ddf.Data_Type__c) || ddCoreService.FIELD_TRUNCTYPES_PSEUDOCOUNTABLE.contains(ddf.Data_Type_Details_Trunc__c))) {
                    totalUsage = 0;
                    try {
                        // List<AggregateResult> groupedResults = Database.query('SELECT Count(' + ddf.API_Name__c + ') FROM ' + ddf.Object__r.API_Name__c);
                        List<AggregateResult> groupedResults = Database.query('SELECT Count(Id) FROM ' + ddf.Object__r.API_Name__c + ' WHERE ' + ddf.API_Name__c + ' != null');

                        for (AggregateResult ar : groupedResults) {
                            totalUsage = totalUsage + (Integer)ar.get('expr0');
                        }
                    } catch (Exception ex) {
                        System.debug('Error in COUNT(Id) query for field ' + ddf.API_Name__c);
                        throw ex;
                    }
                }
            }

            ddf.Usage_Count__c = totalUsage;

            // Calculate usage by record type



            // Calculate picklist values by record type (only for picklist fields)



            // Dependent picklist tree


            // Calculate dependecies (including use in reports)


            // Get the most recent report last run date from any of those reports

        }

        update records;
    }

    public void finish(Database.BatchableContext bc) {
    }    

}
