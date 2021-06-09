public with sharing class ddObjectFields {

    private Data_Dictionary_Object__c ddo;
    private List<Data_Dictionary_Field__c> fields;
    private Map<String, Data_Dictionary_Field__c> fieldMap;
    //private Map<String, Integer> fieldPosMap;
    private List<FieldDefinition> fieldDefs;
    private Map<String, FieldDefinition> fieldDefMap;
    private List<String> newList;

    private List<String> messages;

    public ddObjectFields() {
        this.ddo = new Data_Dictionary_Object__c();
        this.fields = new List<Data_Dictionary_Field__c>();
        this.fieldDefMap = new Map<String, FieldDefinition>();

        this.fieldMap = new Map<String, Data_Dictionary_Field__c>();
        //this.fieldPosMap = new Map<String, Integer>();
    }

    public Boolean SetObjectId(Id idVal) {
        // TODO: validate idVal
        this.ddo.Id = idVal;
        
        return true;
    }

    public Boolean SetObjectAPIName(String apiName) {
        this.ddo.API_Name__c = apiName;
        
        return true;
    }

    public Boolean SetObjectDurableId(String durableId) {
        this.ddo.Durable_ID__c = durableId;

        return true;
    }

    public Boolean Fill() {
        this.fillFromDDFs();
        this.fillFromFieldDefs();
        this.fillFromDescribe();
        this.updateFieldMap();

        this.fillCreateDates();

        this.fillPermissions();
        this.fillOwnership();
        this.fillPageLayouts();

        return true;
    }

    public Boolean fillFromDDFs() {
        // Get the Data Dictionary data
        List<Data_Dictionary_Field__c> ddfList = [
            SELECT Id, Durable_ID__c, Name, API_Name__c, Field_ID__c, Last_Processed__c, Help_Text__c, Description__c
            FROM Data_Dictionary_Field__c
            WHERE Object__c = :this.ddo.Id
        ];

        this.fields = ddfList;

        this.updateFieldMap();

        return true;
    }

    private void updateFieldMap() {
        for (Data_Dictionary_Field__c ddf : this.fields) {
            this.fieldMap.put(ddf.API_Name__c, ddf);
        }
    }

    private List<Object> getCustomFieldToolingData() {
        String baseURL = URL.getSalesforceBaseUrl().toExternalForm();
        String DeveloperName = this.ddo.API_Name__c.removeEndIgnoreCase('__c').removeEndIgnoreCase('__b').removeEndIgnoreCase('__e');
        String fieldList = '(\'' + String.join(this.newList, '\',\'') + '\')';

        String body = ddCoreService.httpGet(baseURL +
            '/services/data/' + ddCoreService.getActiveSettings().Tooling_API_Version__c + '/tooling/query?' +
            'q=' + EncodingUtil.urlEncode('SELECT DeveloperName, CreatedDate, CreatedById FROM CustomField WHERE DeveloperName IN ' + fieldList + ' AND TableEnumOrId = \'' + this.ddo.Id + '\'', 'UTF-8'),
            'GET', ddCoreService.GetUserSessionId());
   
        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(body);

        List<Object> data = (List<Object>)responseMap.get('records');

        return data;
    }

    private Boolean fillCreateDates() {
        if (this.newList != null && this.newList.size() > 0) {
            List<Object> toolingData = this.getCustomFieldToolingData();
            for (String fieldApi : this.newList) {

            }
        }

        return true;
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
                            tempList.add(layoutMd.FullName.substringAfter('-') + System.Label.Data_Dictionary_Layout_Section_Seperator + sectionName);
                            fieldSections.put(item.field, tempList);
                        }
                    }
                }
            }
        }

        return fieldSections;
    }

    public Boolean fillPageLayouts() {
        Map<String, List<String>> fieldSections = getFieldLayoutMap();

        for (Data_Dictionary_Field__c ddfItem : this.fields) {
            String fieldPageLayouts = '';
            if (fieldSections.containsKey(ddfItem.API_Name__c)) {
                fieldPageLayouts = String.join(fieldSections.get(ddfItem.API_Name__c), '\n');
            }
            ddfItem.Page_Layouts__c = fieldPageLayouts;
        }

        return true;
    }

    public Boolean fillPermissions() {
        Map<Id, Profile> profilesMap = ddCoreService.getProfilesMap();
        Map<Id, PermissionSetGroup> permGroupsMap = ddCoreService.getPermGroupsMap();

        List<FieldPermissions> fieldPerms = [
            SELECT Parent.Label, Parent.PermissionSetGroupId, Parent.ProfileId, Parent.IsCustom, Field, PermissionsRead, PermissionsEdit 
            FROM FieldPermissions 
            WHERE sObjectType = :this.ddo.API_Name__c
            ORDER BY Parent.Label
        ];

        for (Data_Dictionary_Field__c ddfItem : this.fields) {

            // Field permissions
            String fieldPermsRead = '';
            String fieldPermsEdit = '';
            String fieldPermGroupsRead = '';
            String fieldPermGroupsEdit = '';
            String fieldProfilesRead = '';
            String fieldProfilesEdit = '';

            // TODO: certain fields have implied permissions. For example required fields have read/edit for all profiles.
            for (FieldPermissions fieldPerm : fieldPerms) {
                if (fieldPerm.Field == this.ddo.API_Name__c + '.' + ddfItem.API_Name__c) {
                    if (fieldPerm.Parent.IsCustom && fieldPerm.Parent.ProfileID == null && fieldPerm.Parent.PermissionSetGroupId == null) {
                        if (fieldPerm.PermissionsRead) {
                            fieldPermsRead = fieldPermsRead + fieldPerm.Parent.Label + '\n';
                        }
                        if (fieldPerm.PermissionsEdit) {
                            fieldPermsEdit = fieldPermsEdit + fieldPerm.Parent.Label + '\n';
                        }
                    } else if (fieldPerm.Parent.PermissionSetGroupId != null) {
                        String permGroupName = permGroupsMap.get(fieldPerm.Parent.PermissionSetGroupId).MasterLabel;
                        if (fieldPerm.PermissionsRead) {
                            fieldPermGroupsRead = fieldPermGroupsRead + permGroupName + '\n';
                        }
                        if (fieldPerm.PermissionsEdit) {
                            fieldPermGroupsEdit = fieldPermGroupsEdit + permGroupName + '\n';
                        }
                    } else if (fieldPerm.Parent.ProfileID != null) {
                        String profileName = profilesMap.get(fieldPerm.Parent.ProfileID).Name;
                        if (fieldPerm.PermissionsRead) {
                            fieldProfilesRead = fieldProfilesRead + profileName + '\n';
                        }
                        if (fieldPerm.PermissionsEdit) {
                            fieldProfilesEdit = fieldProfilesEdit + profileName + '\n';
                        }
                    }
                }
            }


            ddfItem.Permission_Set_Groups_Read__c = fieldPermGroupsRead;
            ddfItem.Permission_Set_Groups_Edit__c = fieldPermGroupsEdit;

            ddfItem.Permission_Sets_Read__c = fieldPermsRead;
            ddfItem.Permission_Sets_Edit__c = fieldPermsEdit;

            ddfItem.Profiles_Read__c = fieldProfilesRead;
            ddfItem.Profiles_Edit__c = fieldProfilesEdit;
        }

        return true;
    }

    public Boolean fillOwnership() {
        this.SetFieldDefs();
        Map<Id, Group> publicGroupsMap = ddCoreService.getPublicGroupMap();

        for (FieldDefinition fd : this.fieldDefs) {
            Data_Dictionary_Field__c ddfItem = this.fieldMap.get(fd.QualifiedApiName);

            if (fd.BusinessOwnerId != null) {
                Schema.sObjectType entityType = fd.BusinessOwnerId.getSObjectType();
                if (entityType == User.sObjectType) {
                    ddfItem.Data_Owner_User__c = fd.BusinessOwnerId;
                    ddfItem.Data_Owner_Group_Name__c = null;
                    ddfItem.Data_Owner_Group_ID__c = null;
                } else {
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

        return true;
    }

    public void SetFieldDefs() {
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

    public Boolean fillFromDescribe() {
        List<Schema.DescribeSobjectResult> results = Schema.describeSObjects(new List<String>{this.ddo.API_Name__c});
        Map<String, Schema.SObjectField> fieldMap = results[0].fields.getMap();

        for (FieldDefinition fd : this.fieldDefs) {
            if (fieldMap.containsKey(fd.QualifiedApiName.toLowerCase())) {
                Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fd.QualifiedApiName.toLowerCase()).getDescribe();
                Data_Dictionary_Field__c ddfItem = this.fieldMap.get(fd.QualifiedApiName);

                // Field ID
                if (fieldDescribe.isCustom()) {
                    ddfItem.Field_ID__c = fd.DurableId.substringAfter('.');
                } else {
                    ddfItem.Field_ID__c = '';
                }

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
                    ddfItem.Picklist_Values_Simple__c = pickField;
                }

                // Dependent picklists
                if (fieldDescribe.isDependentPicklist()) {
                    ddfItem.Is_Dependent_Picklist__c = true;
                    // TODO: more here
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

        return true;
    }

    public Boolean fillFromFieldDefs() {
        this.SetFieldDefs();

        for (FieldDefinition fd : this.fieldDefs) {
            Data_Dictionary_Field__c ddfItem = new Data_Dictionary_Field__c();
            
            // fieldPos is the postion in this.fields of this field
            Integer fieldPos = -1;

            for (Data_Dictionary_Field__c ddf : this.fields) {
                if (ddf.Durable_ID__c == fd.DurableId) {
                    ddfItem.Id = ddf.Id;
                    fieldPos = this.fields.indexOf(ddf);
                    break;
                }
            }

            ddfItem.Status__c = ddCoreService.FIELD_STATUS_ACTIVE;

            ddfItem.Name = fd.Label;
            ddfItem.API_Name__c = fd.QualifiedApiName;
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

            ddfItem.Metadata_Last_Modified_by__c = fd.LastModifiedById;
            ddfItem.Metadata_Last_Modified_Date__c = fd.LastModifiedDate;

            ddfItem.Last_Processed__c = Datetime.now();

            if (fieldPos > -1) {
                this.fields.set(fieldPos, ddfItem);
            } else {
                ddfItem.Object__c = this.ddo.Id;
                ddfItem.First_Sync__c = Datetime.now();
                this.newList.add(ddfItem.API_Name__c);

                this.fields.add(ddfItem);
            }
        }

        // TODO: if there are fields that were not processed, they must have been deleted or are still draft

        return true;
    }


    public String Save() {
        try {
            upsert this.fields;
            return 'success';
        } catch (Exception ex) {
            return ex.getMessage();
        }
    }

}
