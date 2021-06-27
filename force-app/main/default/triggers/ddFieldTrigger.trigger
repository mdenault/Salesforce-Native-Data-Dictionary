trigger ddFieldTrigger on Data_Dictionary_Field__c (after update) {
    List<Data_Dictionary_Change_Log__c> logList = new List<Data_Dictionary_Change_Log__c>();

    Data_Dictionary_Setting__mdt settings = ddCoreService.getActiveSettings();
    List<String> excludeFieldNames = ddCoreService.getListFromSetting('DDF_Fields_Exclude_from_Log__c', settings);
    excludeFieldNames = ddCoreService.lowercaseList(excludeFieldNames);

    // TODO: probably more fields to add here
    List<String> nativeFieldNames = new List<String>{'page_layouts__c', 'permission_set_groups_edit__c', 'permission_set_groups_read__c', 'permission_sets_edit__c', 'permission_sets_read__c', 'profiles_edit__c', 'profiles_read__c'};

    Map<String, Schema.SObjectField> fieldsMap = Schema.SObjectType.Data_Dictionary_Field__c.fields.getMap();
    Set <String> fieldNames = fieldsMap.keySet();
    for (Data_Dictionary_Field__c ddfRecord : trigger.new) {
        for (String field : fieldNames) {
            // What we're doing here is checking that 1) this isn't a field that is a part of the Data Dictionary
            // system being populated in the initial phased population, 2) that it isn't in the list of excluded
            // fields, and 3) that the value actually has changed.
            if (!(ddfRecord.Last_Processed__c == null && nativeFieldNames.contains(field)) &&
            excludeFieldNames.contains(field) == false && 
            ddfRecord.get(field) != trigger.oldMap.get(ddfRecord.Id).get(field)) {
                Data_Dictionary_Change_Log__c log = new Data_Dictionary_Change_Log__c();
                log.Field__c = ddfRecord.Id;
                log.Object__c = ddfRecord.Object__c;
                log.Element__c = fieldsMap.get(field).getDescribe().getLabel();
                log.Prior_Value__c = ddCoreService.longString(String.valueOf(trigger.oldMap.get(ddfRecord.Id).get(field)), 131072);
                log.New_Value__c = ddCoreService.longString(String.valueOf(trigger.newMap.get(ddfRecord.Id).get(field)), 131072);
                logList.add(log);
            }
        }
    }

    if (logList.size() > 0) {
        insert logList;
    }

}