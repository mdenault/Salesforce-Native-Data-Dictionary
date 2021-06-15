public with sharing class ddFieldList {

    private List<Data_Dictionary_Field__c> fieldList;

    public ddFieldList(List<Data_Dictionary_Field__c> fieldList) {
        this.fieldList = fieldList;
    }


    public Boolean setRecordCounts() {
        for (Data_Dictionary_Field__c ddf : records) {
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
        }
    }


    public String Save() {
        try {
            upsert this.fieldList;
            return 'success';
        } catch (Exception ex) {
            return ex.getMessage();
        }
    }


}
