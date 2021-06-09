trigger ddFieldTrigger on Data_Dictionary_Field__c (after update) {
    List<Data_Dictionary_Change_Log__c> logList = new List<Data_Dictionary_Change_Log__c>();

    Data_Dictionary_Setting__mdt settings = ddCoreService.getActiveSettings();
    List<String> excludeFieldNames = ddCoreService.getListFromSetting('DDF_Fields_Exclude_from_Log__c', settings);
    excludeFieldNames = ddCoreService.lowercaseList(excludeFieldNames);

    Map<String, Schema.SObjectField> fieldsMap = Schema.SObjectType.Data_Dictionary_Field__c.fields.getMap();
    Set <String> fieldNames = fieldsMap.keySet();
    for (Data_Dictionary_Field__c ddfRecord : trigger.new) {
        for (String field : fieldNames) {
            if (excludeFieldNames.contains(field) == false && ddfRecord.get(field) != trigger.oldMap.get(ddfRecord.Id).get(field)) {
                Data_Dictionary_Change_Log__c log = new Data_Dictionary_Change_Log__c();
                log.Field__c = ddfRecord.Id;
                log.Object__c = ddfRecord.Object__c;
                log.Element__c = fieldsMap.get(field).getDescribe().getLabel();
                log.Prior_Value__c = String.valueOf(trigger.oldMap.get(ddfRecord.Id).get(field));
                log.New_Value__c = String.valueOf(trigger.newMap.get(ddfRecord.Id).get(field));
                logList.add(log);
            }
        }
    }

    if (logList.size() > 0) {
        insert logList;
    }

}