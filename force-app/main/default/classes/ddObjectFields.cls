public with sharing class ddObjectFields {

    private Data_Dictionary_Object__c ddo;
    private List<Data_Dictionary_Field__c> fields;
    private Map<String, Data_Dictionary_Field__c> fieldMap;
    private List<FieldDefinition> fieldDefs;
    private Map<String, FieldDefinition> fieldDefMap;
    private List<String> newList;

    private List<String> messages;

    public ddObjectFields() {
        this.ddo = new Data_Dictionary_Object__c();
        this.fields = new List<Data_Dictionary_Field__c>();
        this.fieldDefMap = new Map<String, FieldDefinition>();
        this.fieldMap = new Map<String, Data_Dictionary_Field__c>();
        this.newList = new List<String>();
    }

    public void setObjectId(Id idVal) {
        this.ddo.Id = idVal;
    }

    public void setObjectAPIName(String apiName) {
        this.ddo.API_Name__c = apiName;
    }

    public void setObjectDurableId(String durableId) {
        this.ddo.Durable_ID__c = durableId;
    }

    public void fillFromDDFs() {
        // Get the Data Dictionary data
        List<Data_Dictionary_Field__c> ddfList = [
            SELECT Id, Status__c, Durable_ID__c, Name, API_Name__c, Field_ID__c, Last_Processed__c, Help_Text__c, Description__c
            FROM Data_Dictionary_Field__c
            WHERE Object__c = :this.ddo.Id
        ];

        this.fields = ddfList;

        this.updateFieldMap();
    }

    public void updateFieldMap() {
        for (Data_Dictionary_Field__c ddf : this.fields) {
            this.fieldMap.put(ddf.API_Name__c, ddf);
        }
    }

    private List<Object> getCustomFieldToolingData() {
        List<Object> data = new List<Object>();
        
        String baseURL = URL.getSalesforceBaseUrl().toExternalForm();
        String DeveloperName = this.ddo.API_Name__c.removeEndIgnoreCase('__c').removeEndIgnoreCase('__b').removeEndIgnoreCase('__e');
        
        // We can only look up custom fields, and only by DeveloperName which is the bit before the "__c"
        List<String> newFieldDevNames = new List<String>();
        for (String s : this.newList) {
            if (s.endsWithIgnoreCase('__c')) {
                newFieldDevNames.add(s.removeEndIgnoreCase('__c'));
            }
        }

        if (newFieldDevNames.size() > 0) {
            String fieldList = '(\'' + String.join(newFieldDevNames, '\',\'') + '\')';

            String body = ddCoreService.httpGet(baseURL +
                '/services/data/' + ddCoreService.getActiveSettings().Tooling_API_Version__c + '/tooling/query?' +
                'q=' + EncodingUtil.urlEncode('SELECT DeveloperName, CreatedDate, CreatedById FROM CustomField WHERE DeveloperName IN ' + fieldList + ' AND TableEnumOrId = \'' + this.ddo.Durable_ID__c + '\'', 'UTF-8'),
                'GET', ddCoreService.GetUserSessionId());

            Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(body);
            data = (List<Object>)responseMap.get('records');
        }

        return data;
    }

    public void fillCreateDates() {
        if (this.newList != null && this.newList.size() > 0) {
            List<Object> toolingData = this.getCustomFieldToolingData();
            for (Object obj : toolingData) {
                Map<String, Object> record = (Map<String, Object>)obj;

                for (Data_Dictionary_Field__c ddfItem : this.fields) {
                    if (ddfItem.API_Name__c.endsWithIgnoreCase('__c') && ddfItem.API_Name__c.removeEndIgnoreCase('__c') == (String)record.get('DeveloperName')) {
                        if (record.containsKey('CreatedDate')) {
                            ddfItem.Field_Created_Date__c = Datetime.valueOfGmt(ddCoreService.formatDateTime((String)record.get('CreatedDate')));
                        }
                        if (record.containsKey('CreatedById')) {
                            ddfItem.Field_Created_by__c = (String)record.get('CreatedById');
                        }
                        break;
                    }
                }

                record = null;
            }
        }
    }

    private Map<String, List<String>> getFieldLayoutMap() {
        List<Metadata.Metadata> pageLayouts = ddCoreService.getPageLayoutsForObjectDurableId(this.ddo.Durable_ID__c, this.ddo.API_Name__c);

        Map<String, List<String>> fieldSections = new Map<String, List<String>>();
        for (Metadata.Metadata pl : pageLayouts) {
            String sectionName = '';
            Metadata.Layout layoutMd = (Metadata.Layout) pl;
            for (Metadata.LayoutSection section : layoutMd.layoutSections) {
                sectionName = section.label;
                for (Metadata.LayoutColumn column : section.layoutColumns) {
                    if (column.layoutItems != null) {
                        for (Metadata.LayoutItem item : column.layoutItems) {
                            if (fieldSections.containsKey(item.field) == false) {
                                fieldSections.put(item.field, new List<String>());
                            }
                            List<String> tempList = fieldSections.get(item.field);
                            tempList.add(layoutMd.FullName.substringAfter('-') + ' ' + System.Label.Data_Dictionary_Layout_Section_Seperator + ' ' + sectionName);
                            fieldSections.put(item.field, tempList);
                        }
                    }
                }
            }
        }

        return fieldSections;
    }

    public void fillPageLayouts() {
        Map<String, List<String>> fieldSections = getFieldLayoutMap();

        for (Data_Dictionary_Field__c ddfItem : this.fields) {
            String fieldPageLayouts = '';
            if (fieldSections.containsKey(ddfItem.API_Name__c)) {
                fieldPageLayouts = String.join(fieldSections.get(ddfItem.API_Name__c), '\n');
            }
            ddfItem.Page_Layouts__c = fieldPageLayouts;
        }
    }

    public void fillPermissions() {
        Map<Id, Profile> profilesMap = ddCoreService.getProfilesMap();
        Map<Id, PermissionSetGroup> permGroupsMap = ddCoreService.getPermGroupsMap();

        // We're going to store permission data in this nested map. The outer key will be the field
        // API name, and the inner map will be keys to the different types of permissions, and a 
        // list of strings representing the name of the permission set/perm set group/profile.
        Map<String, Map<String, List<String>>> permMap = new Map<String, Map<String, List<String>>>();

        // Set up the map
        for (Data_Dictionary_Field__c ddfItem : this.fields) {
            if (ddfItem.Status__c == ddCoreService.FIELD_STATUS_ACTIVE) {
                Map<String, List<String>> innerMap = new Map<String, List<String>>();
                innerMap.put('fieldPermsReadMap', new List<String>());
                innerMap.put('fieldPermsEditMap', new List<String>());
                innerMap.put('fieldPermGroupsReadMap', new List<String>());
                innerMap.put('fieldPermGroupsEditMap', new List<String>());
                innerMap.put('fieldProfilesReadMap', new List<String>());
                innerMap.put('fieldProfilesEditMap', new List<String>());

                permMap.put(ddfItem.API_Name__c, innerMap);

                innerMap = null;
            }
        }

        for (List<FieldPermissions> fieldPerms : [
            SELECT Parent.Label, Parent.PermissionSetGroupId, Parent.ProfileId, Parent.IsCustom, Field, PermissionsRead, PermissionsEdit 
            FROM FieldPermissions 
            WHERE sObjectType = :this.ddo.API_Name__c
            ORDER BY Parent.Label
        ]) {
            for (FieldPermissions fieldPerm : fieldPerms) {
                String fieldApiName = fieldPerm.Field.substringAfterLast('.');
                String type = '';
                String label = '';
                if (fieldPerm.Parent.IsCustom && fieldPerm.Parent.ProfileID == null && fieldPerm.Parent.PermissionSetGroupId == null) {
                    label = fieldPerm.Parent.Label;
                    if (fieldPerm.PermissionsRead) {
                        type = 'fieldPermsReadMap';
                    }
                    if (fieldPerm.PermissionsEdit) {
                        type = 'fieldPermsEditMap';
                    }
                } else if (fieldPerm.Parent.PermissionSetGroupId != null) {
                    label = permGroupsMap.get(fieldPerm.Parent.PermissionSetGroupId).MasterLabel;
                    if (fieldPerm.PermissionsRead) {
                        type = 'fieldPermGroupsReadMap';
                    }
                    if (fieldPerm.PermissionsEdit) {
                        type = 'fieldPermGroupsEditMap';
                    }
                } else if (fieldPerm.Parent.ProfileID != null) {
                    label = profilesMap.get(fieldPerm.Parent.ProfileID).Name;
                    if (fieldPerm.PermissionsRead) {
                        type = 'fieldProfilesReadMap';
                    }
                    if (fieldPerm.PermissionsEdit) {
                        type = 'fieldProfilesEditMap';
                    }
                }

                if (String.isNotEmpty(type) && permMap.containsKey(fieldApiName)) {
                    List<String> temp = permMap.get(fieldApiName).get(type);
                    temp.add(label);
                    permMap.get(fieldApiName).put(type, temp);
                    temp = null;
                }

                fieldPerm = null;
            }

            fieldPerms = null;
        }

        // Null out no-longer needed data to conserve heap space
        profilesMap = null;
        permGroupsMap = null;

        Integer pMax = 20000;

        for (Data_Dictionary_Field__c ddfItem : this.fields) {
            // Empty out any existing data
            ddfItem.Permission_Set_Groups_Read__c = '';
            ddfItem.Permission_Set_Groups_Edit__c = '';
            ddfItem.Permission_Sets_Read__c = '';
            ddfItem.Permission_Sets_Edit__c = '';
            ddfItem.Profiles_Read__c = '';
            ddfItem.Profiles_Edit__c = '';

            if (1 == 1) { // (ddfItem.Status__c == ddCoreService.FIELD_STATUS_ACTIVE) {
                if (permMap.get(ddfItem.API_Name__c).get('fieldPermGroupsReadMap').size() > 0) {
                    ddfItem.Permission_Set_Groups_Read__c = ddCoreService.longString(String.join(permMap.get(ddfItem.API_Name__c).get('fieldPermGroupsReadMap'), '\n'), pMax);
                }

                if (permMap.get(ddfItem.API_Name__c).get('fieldPermGroupsEditMap').size() > 0) {
                    ddfItem.Permission_Set_Groups_Edit__c = ddCoreService.longString(String.join(permMap.get(ddfItem.API_Name__c).get('fieldPermGroupsEditMap'), '\n'), pMax);
                }

                if (permMap.get(ddfItem.API_Name__c).get('fieldPermsReadMap').size() > 0) {
                    ddfItem.Permission_Sets_Read__c = ddCoreService.longString(String.join(permMap.get(ddfItem.API_Name__c).get('fieldPermsReadMap'), '\n'), pMax);
                }

                if (permMap.get(ddfItem.API_Name__c).get('fieldPermsEditMap').size() > 0) {
                    ddfItem.Permission_Sets_Edit__c = ddCoreService.longString(String.join(permMap.get(ddfItem.API_Name__c).get('fieldPermsEditMap'), '\n'), pMax);
                }

                if (permMap.get(ddfItem.API_Name__c).get('fieldProfilesReadMap').size() > 0) {
                    ddfItem.Profiles_Read__c = ddCoreService.longString(String.join(permMap.get(ddfItem.API_Name__c).get('fieldProfilesReadMap'), '\n'), pMax);
                }
                
                if (permMap.get(ddfItem.API_Name__c).get('fieldProfilesEditMap').size() > 0) {
                    ddfItem.Profiles_Edit__c = ddCoreService.longString(String.join(permMap.get(ddfItem.API_Name__c).get('fieldProfilesEditMap'), '\n'), pMax);
                }

                // Again, remove not-longer needed values to reduce heap usage
                permMap.remove(ddfItem.API_Name__c);
            }
        }
    }

    public void fillOwnership() {
        this.SetFieldDefs();
        Map<Id, Group> publicGroupsMap = ddCoreService.getPublicGroupMap();

        for (FieldDefinition fd : this.fieldDefs) {
            if (this.fieldMap.containsKey(fd.QualifiedApiName)) {
                Data_Dictionary_Field__c ddfItem = this.fieldMap.get(fd.QualifiedApiName);
                if (fd.BusinessOwnerId != null) {
                    Schema.sObjectType entityType = fd.BusinessOwnerId.getSObjectType();
                    if (entityType == User.sObjectType) {
                        ddfItem.Data_Owner_User__c = fd.BusinessOwnerId;
                        ddfItem.Data_Owner_Group_Name__c = null;
                        ddfItem.Data_Owner_Group_ID__c = null;
                    } else {
                        // Salesforce doesn't allow lookup fields to public groups so best to store the group name
                        // and ID in separate fields.
                        ddfItem.Data_Owner_User__c = null;
                        ddfItem.Data_Owner_Group_Name__c = ddCoreService.getPublicGroupNameById(fd.BusinessOwnerId, publicGroupsMap);
                        ddfItem.Data_Owner_Group_ID__c = fd.BusinessOwnerId;
                    }
                } else {
                    ddfItem.Data_Owner_User__c = null;
                    ddfItem.Data_Owner_Group_Name__c = null;
                    ddfItem.Data_Owner_Group_ID__c = null;
                }
            }
        }
    }

    public void setFieldDefs() {
        if (this.fieldDefs == null || this.fieldDefs.size() == 0) {
            List<String> excludedFields = ddCoreService.getListFromSetting('Field_Names_to_Exclude__c', ddCoreService.getActiveSettings());

            // TODO: there may be a limit of 200 here, in which case we need to do this in a loop
            List<FieldDefinition> fieldDefinitions = [
                SELECT Id, BusinessOwnerId, BusinessStatus, ComplianceGroup, DataType, Description, DurableId, IsCompound, IsFieldHistoryTracked, IsNameField, IsNillable, Label, Length, Precision, Scale, LastModifiedById, LastModifiedDate, NamespacePrefix, QualifiedApiName, RelationshipName, SecurityClassification
                FROM FieldDefinition
                WHERE EntityDefinition.DurableId = :this.ddo.Durable_ID__c
                AND QualifiedApiName NOT IN :excludedFields
            ];

            this.fieldDefs = fieldDefinitions;
        }
    }

    public Boolean fieldIsRequired(Schema.DescribeFieldResult field) {
        return ((field.isCreateable() == true && field.isDefaultedOnCreate() == false && field.isNillable() == false) || (field.isNameField() == true && field.isAutoNumber() == false));
    }

    public void fillFromDescribe() {
        List<Schema.DescribeSobjectResult> results = Schema.describeSObjects(new List<String>{this.ddo.API_Name__c});
        Map<String, Schema.SObjectField> fieldDescMap = results[0].fields.getMap();

        for (FieldDefinition fd : this.fieldDefs) {
            if (fieldDescMap.containsKey(fd.QualifiedApiName.toLowerCase()) && this.fieldMap.containsKey(fd.QualifiedApiName)) {
                Schema.DescribeFieldResult fieldDescribe = fieldDescMap.get(fd.QualifiedApiName.toLowerCase()).getDescribe();
                Data_Dictionary_Field__c ddfItem = this.fieldMap.get(fd.QualifiedApiName);

                // Field ID
                if (fieldDescribe.isCustom()) {
                    ddfItem.Field_ID__c = fd.DurableId.substringAfter('.');
                } else {
                    ddfItem.Field_ID__c = '';
                }

                // Required
                ddfItem.Is_Required__c = fieldIsRequired(fieldDescribe);

                // Uniqueness
                if (fieldDescribe.isUnique()) {
                    ddfItem.Is_Unique__c = true;
                    ddfItem.Is_Case_Sensitive__c = fieldDescribe.isCaseSensitive();
                } else {
                    ddfItem.Is_Unique__c = false;
                    ddfItem.Is_Case_Sensitive__c = false;
                }

                // External ID
                ddfItem.Is_External_ID__c = fieldDescribe.isExternalId();

                // Help text
                ddfItem.Help_Text__c = fieldDescribe.getInlineHelpText();

                // Get all picklist values
                if (String.valueOf(fieldDescribe.getType()) == 'PICKLIST') {
                    String pickField = '';
                    List<Schema.PicklistEntry> picks = fieldDescribe.getPicklistValues();
                    for (Schema.PicklistEntry pick : picks) {
                        if (pick.isActive()) {
                            pickField += pick.getLabel() + '\n';
                        }
                    }
                    ddfItem.Picklist_Values_Simple__c = ddCoreService.longString(pickField, 20000);
                    ddfItem.Picklist_Values_All__c = ddCoreService.longString(JSON.serializePretty(picks), 40000);
                }

                // Dependent picklists
                if (fieldDescribe.isDependentPicklist()) {
                    ddfItem.Is_Dependent_Picklist__c = true;
                    // TODO: more here?
                } else {
                    ddfItem.Is_Dependent_Picklist__c = false;
                }
                
                // Standard fields
                if (fieldDescribe.isCustom()) {
                    ddfItem.Type__c = ddCoreService.FIELD_TYPE_CUSTOM;
                } else {
                    ddfItem.Type__c = ddCoreService.FIELD_TYPE_STANDARD;
                }

                // Formula
                if (fieldDescribe.isCalculated()) {
                    ddfItem.Is_Formula__c = true;
                    ddfItem.Value_Formula__c = fieldDescribe.getCalculatedFormula();
                } else {
                    ddfItem.Is_Formula__c = false;
                    ddfItem.Value_Formula__c = '';
                }

                // Default value
                ddfItem.Is_Auto_Number__c = fieldDescribe.isAutoNumber();
                ddfItem.Default_Value__c = fieldDescribe.getDefaultValueFormula();
                if (String.isNotBlank(ddfItem.Default_Value__c)) {
                    ddfItem.Is_Default_Value_Formula__c = true;
                } else {
                    ddfItem.Is_Default_Value_Formula__c = false;
                    ddfItem.Default_Value__c = String.valueOf(fieldDescribe.getDefaultValue());
                }

            }
        }
    }

    public void fillFromFieldDefs() {
        this.setFieldDefs();

        // This is a list of the fields that we saw as active in the last run. If any of them are left over
        // after this pass, that means they were deleted.
        List<String> unprocessedDurIds = new List<String>();
        for (Data_Dictionary_Field__c ddf : this.fields) {
            if (ddf.Durable_ID__c != null && ddf.Status__c == ddCoreService.FIELD_STATUS_ACTIVE) {
                unprocessedDurIds.add(ddf.Durable_ID__c);
            }
        }

        for (FieldDefinition fd : this.fieldDefs) {
            Boolean wasDraft = false;
            Data_Dictionary_Field__c ddfItem = new Data_Dictionary_Field__c();

            for (Data_Dictionary_Field__c ddf : this.fields) {
                // Either we match active fields, or we have a field that was previously draft or deleted that has been (re)created
                if (fd.DurableId.equals(ddf.Durable_ID__c) || fd.QualifiedApiName == ddf.API_Name__c) {
                    ddfItem = this.fields.get(this.fields.indexOf(ddf));
                    // We found this field, so remove it from our unprocessed list if we can
                    Integer unprocIndex = unprocessedDurIds.indexOf(fd.DurableId);
                    if (unprocIndex >= 0) {
                        unprocessedDurIds.remove(unprocIndex);
                    } else if (ddf.Status__c == ddCoreService.FIELD_STATUS_DRAFT) {
                        wasDraft = true;
                    }
                    // And then exit the loop
                    break;
                }
            }

            ddfItem.Status__c = ddCoreService.FIELD_STATUS_ACTIVE;

            ddfItem.Name = fd.Label;
            ddfItem.API_Name__c = fd.QualifiedApiName;
            ddfItem.Namespace__c = fd.NamespacePrefix;
            ddfItem.Description__c = fd.Description;

            ddfItem.Length__c = fd.Length;
            ddfItem.Precision__c = fd.Precision;
            ddfItem.Scale__c = fd.Scale;

            ddfItem.Relationship_Name__c = fd.RelationShipName;

            ddfItem.History_Tracked__c = fd.IsFieldHistoryTracked;

            // Data Type
            ddfItem.Field_Type_Details__c = fd.DataType;
            ddfItem.Data_Type_Details_Trunc__c = fd.DataType.left(100);
            ddfItem.Data_Type__c = ddfItem.Field_Type_Details__c.substringBefore('(');

            // Classifications
            ddfItem.Indicated_Field_Usage__c = fd.BusinessStatus;
            ddfItem.Compliance_Categorization__c = fd.ComplianceGroup;
            ddfItem.Data_Sensitivity_Level__c = fd.SecurityClassification;

            // DurableID
            ddfItem.Durable_ID__c = fd.DurableId;

            // Last modified
            ddfItem.Metadata_Last_Modified_by__c = fd.LastModifiedById;
            ddfItem.Metadata_Last_Modified_Date__c = fd.LastModifiedDate;

            Datetime curDateTime = Datetime.now();

            if (ddfItem.Id != null && wasDraft == false) {
                ddfItem.Last_Processed__c = curDateTime;
            } else {
                ddfItem.Object__c = this.ddo.Id;
                ddfItem.First_Sync__c = curDateTime;
                this.newList.add(ddfItem.API_Name__c);

                if (wasDraft == false) {
                    this.fields.add(ddfItem);
                }
            }
        }

        // If there are fields that were not processed, they may have been deleted (or they are still draft)
        for (String durId : unprocessedDurIds) {
            for (Data_Dictionary_Field__c ddf : this.fields) {
                if (durId == ddf.Durable_ID__c && ddf.Status__c == ddCoreService.FIELD_STATUS_ACTIVE) {
                    ddf.Status__c = ddCoreService.FIELD_STATUS_DELETED;
                    ddf.Last_Processed__c = Datetime.now();
                }
            }
        }
    }


    public void save() {
        upsert this.fields;
    }

}
