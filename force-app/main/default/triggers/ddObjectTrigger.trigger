trigger ddObjectTrigger on Data_Dictionary_Object__c (after update) {
    List<Data_Dictionary_Change_Log__c> logList = new List<Data_Dictionary_Change_Log__c>();

    Data_Dictionary_Setting__mdt settings = ddCoreService.getActiveSettings();
    List<String> excludeFieldNames = ddCoreService.getListFromSetting('DDO_Fields_Exclude_from_Log__c', settings);
    excludeFieldNames = ddCoreService.lowercaseList(excludeFieldNames);

    Map<String, Schema.SObjectField> fieldsMap = Schema.SObjectType.Data_Dictionary_Object__c.fields.getMap();
    Set <String> fieldNames = fieldsMap.keySet(); 
    for (Data_Dictionary_Object__c ddoRecord : trigger.new) {
        if (trigger.oldMap.get(ddoRecord.Id).Status__c != ddCoreService.OBJECT_STATUS_STUB) {
            for (String field : fieldNames){
                if (excludeFieldNames.contains(field) == false && ddoRecord.get(field) != trigger.oldMap.get(ddoRecord.Id).get(field)) {
                    Data_Dictionary_Change_Log__c log = new Data_Dictionary_Change_Log__c();
                    log.Object__c = ddoRecord.Id;
                    log.Element__c = fieldsMap.get(field).getDescribe().getLabel();
                    log.Prior_Value__c = ddCoreService.longString(String.valueOf(trigger.oldMap.get(ddoRecord.Id).get(field)), 131072);
                    log.New_Value__c = ddCoreService.longString(String.valueOf(trigger.newMap.get(ddoRecord.Id).get(field)), 131072);
                    logList.add(log);
                }
            }
        }
    }

    if (logList.size() > 0) {
        insert logList;
    }

}