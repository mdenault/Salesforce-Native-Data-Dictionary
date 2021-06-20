public with sharing class ddCoreService {

    public static final String OBJECT_STATUS_STUB = 'Stub';
    public static final String OBJECT_STATUS_DRAFT = 'Projected';
    public static final String OBJECT_STATUS_ACTIVE = 'Active';
    public static final String OBJECT_STATUS_DELETED = 'Deleted';

    public static final String OBJECT_TYPE_STANDARDOBJECT = 'Standard Object';
    public static final String OBJECT_TYPE_CUSTOMOBJECT = 'Custom Object';
    public static final String OBJECT_TYPE_EXTERNALOBJECT = 'External Object';
    public static final String OBJECT_TYPE_CUSTOMSETTING = 'Custom Setting';
    public static final String OBJECT_TYPE_CUSTOMMETADATA = 'Custom Metadata Type';
    public static final String OBJECT_TYPE_BIGOBJECT = 'Big Object';
    public static final String OBJECT_TYPE_PLATFORMEVENT = 'Platform Event';

    public static final String FIELD_TYPE_STANDARD = 'Standard Field';
    public static final String FIELD_TYPE_CUSTOM = 'Custom Field';

    public static final String FIELD_STATUS_DRAFT = 'Draft';
    public static final String FIELD_STATUS_ACTIVE = 'Active';
    public static final String FIELD_STATUS_DELETED = 'Deleted';

    public static final List<String> FIELD_TYPES_COUNTABLE = new List<String>{'Lookup', 'Picklist', 'Text', 'Content', 'URL', 'Number', 'Date/Time', 'Date', 'Email', 'Phone', 'Fax', 'Currency'};
    public static final List<String> FIELD_NAMES_NOTCOUNTABLE = new List<String>{'Id', 'CreatedDate', 'SystemModstamp'};
    public static final List<String> FIELD_TRUNCTYPES_PSEUDOCOUNTABLE = new List<String>{'Checkbox'};

    public static String getUserSessionId() {
        return UserInfo.getSessionId();
    }

    public static String formatDateTime(String utcDate){
    	return utcDate.replace('T', ' ');
    }

    public static Map<Id, Profile> getProfilesMap() {
        List<Profile> profiles = [
            SELECT Id, Name
            FROM Profile
            ORDER BY Name
        ];
        return new Map<Id, Profile>(profiles);
    }

    public static Map<Id, Group> getPublicGroupMap() {
        List<Group> groups = [
            SELECT Id, Name
            FROM Group
            WHERE Type = 'Regular'
            ORDER BY Name
        ];
        return new Map<Id, Group>(groups);
    }

    public static String getPublicGroupNameById(Id groupId, Map<Id, Group> groupMap) {
        if (groupMap.containsKey(groupId)) {
            return groupMap.get(groupId).Name;
        } else {
            return null;
        }
    }

    public static Map<Id, PermissionSetGroup> getPermGroupsMap() {
        List<PermissionSetGroup> permGroups = [
            SELECT Id, MasterLabel
            FROM PermissionSetGroup
            ORDER BY MasterLabel
        ];
        return new Map<Id, PermissionSetGroup>(permGroups);
    }

    public static String httpGet(String endPoint, String method, String sessionId) {
        Http h = new Http();
        HttpRequest hr = new HttpRequest();
        hr.setHeader('Authorization', 'Bearer ' + sessionId);
        hr.setTimeout(60000);
        hr.setEndpoint(endPoint);
        hr.setMethod(method);
        HttpResponse r = h.send(hr);
        return r.getBody();
    }

    // TODO: move these two to ObjectService
    public static List<String> getPageLayoutNameListForObject(String apiName, String prefix, Boolean addPrefix) {
        List<String> layoutNames = new List<String>();
        String baseURL = URL.getSalesforceBaseUrl().toExternalForm();
    
        // TODO: put Tooling API version in custom metadata?
        String body = httpGet(baseURL +
            '/services/data/v51.0/tooling/query?' +
            'q=' + EncodingUtil.urlEncode('SELECT Name FROM Layout WHERE EntityDefinitionId = \'' + apiName + '\' ORDER BY Name', 'UTF-8'),
            'GET', UserInfo.getSessionId());
   
        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(body);

        for (Object data : (List<Object>)responseMap.get('records')) {
            Map<String, Object> record = (Map<String, Object>)data;
            if (addPrefix) {
                String layoutName = String.format('{0}-{1}', new List<String>{prefix, (String)record.get('Name')});
                layoutNames.add(layoutName);
            } else {
                layoutNames.add((String)record.get('Name'));
            }
        }

        return layoutNames;
    }

    public static List<Metadata.Metadata> getPageLayoutsForObjectDurableId(String ddoDurableId, String layoutPrefix) {
        List<Metadata.Metadata> pageLayouts = new List<Metadata.Metadata>();
        List<String> layoutNames = getPageLayoutNameListForObject(ddoDurableId, layoutPrefix, true);

        if (layoutNames.size() > 0) {
            pageLayouts = Metadata.Operations.retrieve(Metadata.MetadataType.Layout, layoutNames);
        }

        return pageLayouts;
    }

    public static List<String> getListFromSetting(String field, Data_Dictionary_Setting__mdt settings) {
        List<String> dataList = new List<String>();
        Map<String, Object> fieldVals = settings.getPopulatedFieldsAsMap();
        if (fieldVals.keySet().contains(field)) {
            String val = (String)fieldVals.get(field);
            dataList = val.split('\n|\r\n');
        }
        return dataList;
    }

    public static List<String> lowercaseList(List<String> strings) {
        List<String> returnList = new List<String>();
        for (String s: strings) {
            returnList.add(s.toLowerCase());
        }
        return returnList;
    }

    public static Data_Dictionary_Setting__mdt getActiveSettings() {
        Data_Dictionary_Setting__mdt setting = new Data_Dictionary_Setting__mdt();
        List<Data_Dictionary_Setting__mdt> mdtSettings = [
            SELECT Id, Standard_Objects_to_Include__c, Namespaces_to_Exclude__c, Custom_Settings_to_Include__c, Custom_Objects_to_Include__c, Custom_Objects_to_Exclude__c, DDF_Fields_Exclude_from_Log__c, DDO_Fields_Exclude_from_Log__c, Field_Names_to_Exclude__c, Custom_Metadata_Types_to_Include__c, Tooling_API_Version__c
            FROM Data_Dictionary_Setting__mdt
            WHERE MasterLabel = 'Active'
        ];
        if (mdtSettings.size() > 0) {
            setting = mdtSettings[0];
        } else {
            setting.Tooling_API_Version__c = 'v51.0';
            setting.Standard_Objects_to_Include__c = 'Account\nCampaign\nCampaignMember\nCase\nContact\nOpportunity\nProduct2';
            setting.Namespaces_to_Exclude__c = '';
            setting.Custom_Objects_to_Include__c = '';
            setting.Custom_Objects_to_Exclude__c = '';
            setting.Custom_Metadata_Types_to_Include__c = 'None';
            setting.DDF_Fields_Exclude_from_Log__c = 'LastModifiedDate\nSystemModstamp\nLast_Processed__c\nData_Owner_Group_Name__c';
            setting.DDO_Fields_Exclude_from_Log__c = 'LastModifiedDate\nSystemModstamp\nLast_Processed__c';
            setting.Field_Names_to_Exclude__c = 'IsDeleted\nSystemModstamp\nLastViewedDate\nLastReferencedDate\nUserRecordAccessId\nSetupOwnerId';
        }

        return setting;
    }


}
