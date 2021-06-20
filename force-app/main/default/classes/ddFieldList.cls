public with sharing class ddFieldList {

    private List<Data_Dictionary_Field__c> fieldList;

    public ddFieldList(List<Data_Dictionary_Field__c> fieldList) {
        this.fieldList = fieldList;
    }

    public static Map<Object, List<Schema.PicklistEntry>> getDependentPicklistValues(String sObjectName, String fieldName) {
        return getDependentPicklistValues(Schema.getGlobalDescribe().get(sObjectName).getDescribe().fields.getMap().get(fieldName));
    }

    /**
    * @description Logic taken from https://glyntalkssalesforce.blogspot.com/2018/08/dependent-picklist-values-in-apex.html and
    * https://salesforce.stackexchange.com/questions/4462/get-lists-of-dependent-picklist-options-in-apex
    * @param Schema.sObjectField dependToken 
    * @return Map<Object, List<Schema.PicklistEntry>> 
    **/
    public static Map<Object, List<Schema.PicklistEntry>> getDependentPicklistValues(Schema.sObjectField dependToken) {
        Schema.DescribeFieldResult depend = dependToken.getDescribe();
        Schema.sObjectField controlToken = depend.getController();
        if (controlToken == null) {
            return null;
        }

        Schema.DescribeFieldResult control = controlToken.getDescribe();
        List<Schema.PicklistEntry> controlEntries = (control.getType() == Schema.DisplayType.Boolean ? null : control.getPicklistValues());
     
        String base64map = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
        Map<Object, List<Schema.PicklistEntry>> dependentPicklistValues = new Map<Object, List<Schema.PicklistEntry>>();
        for (Schema.PicklistEntry entry : depend.getPicklistValues()) {
            if (entry.isActive()) {
                List<String> base64chars = String.valueOf(((Map<String,Object>) JSON.deserializeUntyped(JSON.serialize(entry))).get('validFor')).split('');
                for (Integer index = 0; index < (controlEntries != null ? controlEntries.size() : 2); index++) {
                    Object controlValue = (controlEntries == null ? (Object) (index == 1) : (Object) (controlEntries[index].isActive() ? controlEntries[index].getLabel() : null));

                    // Integer bitIndex = index / 6, bitShift = 5 - Math.mod( index, 6 );
                    Integer bitIndex = index / 6;
                    if (bitIndex > base64chars.size() - 1) {
                        break;
                    }
                    Integer bitShift = 5 - Math.mod( index, 6 );

                    if (controlValue == null || (base64map.indexOf( base64chars[ bitIndex ] ) & (1 << bitShift)) == 0) {
                        continue;
                    }
                    if (!dependentPicklistValues.containsKey(controlValue)) {
                        dependentPicklistValues.put(controlValue, new List<Schema.PicklistEntry>());
                    }
                    dependentPicklistValues.get(controlValue).add(entry);
                }
            }
        }
        return dependentPicklistValues;
    }

    public static PicklistEntries getPicklistValues(String objectName, Id recordTypeId, String fieldName) {
        String requestUrl =
            URL.getSalesforceBaseUrl().toExternalForm() +
            '/services/data/v51.0/ui-api/object-info/' +
            objectName +
            '/picklist-values/' +
            recordTypeId +
            '/' +
            fieldName;

        // Prepare UI API request
        HttpRequest request = new HttpRequest();
        request.setMethod('GET');
        request.setHeader(
            'Authorization',
            'Bearer ' + UserInfo.getSessionId()
        );
        request.setEndpoint(requestUrl);
        // Call UI API
        try {
            HttpResponse httpResponse = new Http().send(request);
            if (httpResponse.getStatusCode() == 200) {
                // Parse JSON response into PicklistEntries
                entries = (PicklistEntries) JSON.deserialize(
                    httpResponse.getBody(),
                    PicklistEntries.class
                );
                // Cache entries
                uiApiCache.put(requestUrl, entries);
            } else {
                System.debug(
                    'HTTP ' +
                    httpResponse.getStatusCode() +
                    ' while calling UI API, Response ' +
                    httpResponse.getBody()
                );
                throw new CalloutException(httpResponse.getBody());
            }
        } catch (System.Exception e) {
            System.debug('ERROR: ' + e);
            throw e;
        }

        return entries;
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


    public String save() {
        try {
            upsert this.fieldList;
            return 'success';
        } catch (Exception ex) {
            return ex.getMessage();
        }
    }


}
