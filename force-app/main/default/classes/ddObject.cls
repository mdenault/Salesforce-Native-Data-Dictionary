public inherited sharing class ddObject {
    
    private Data_Dictionary_Object__c ddo;
    private List<String> messages;

    // We store whether the object metadata record was updated mainly because if it hasn't, we can avoid making the
    // callout to the tooling API to get an updated Description.
    private Boolean metadataUpdated = false;

    public static Map<String, Object> GetCustomObjectToolingData(String QualifiedApiName) {
        Map<String, Object> record = new Map<String, Object>();
        String baseURL = URL.getSalesforceBaseUrl().toExternalForm();

        // TODO: check to see if custom metadata can be retrieved, too
        String DeveloperName = QualifiedApiName.removeEndIgnoreCase('__c').removeEndIgnoreCase('__b').removeEndIgnoreCase('__e');

        String body = ddCoreService.httpGet(baseURL +
            '/services/data/' + ddCoreService.getActiveSettings().Tooling_API_Version__c + '/tooling/query?' +
            'q=' + EncodingUtil.urlEncode('SELECT Description, CreatedDate, CreatedById FROM CustomObject WHERE DeveloperName = \'' + DeveloperName + '\'', 'UTF-8'),
            'GET', ddCoreService.GetUserSessionId());

        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(body);

        List<Object> data = (List<Object>)responseMap.get('records');
        if (data.size() > 0) {
            record = (Map<String, Object>)data[0];
        }
        return record;
    }

    public ddObject() {
        this.ddo = new Data_Dictionary_Object__c();
    }

    public ddObject(Id ddoId, String durableId) {
        this.ddo = new Data_Dictionary_Object__c();
        this.SetId(ddoId);
        this.SetDurableId(durableId);
    }

    public Data_Dictionary_Object__c getDDO() {
        return this.ddo;
    }

    public void setId(Id idVal) {
        this.ddo.Id = idVal;
    }

    public void setDurableId(String durableId) {
        this.ddo.Durable_ID__c = durableId;
    }

    public static String GetObjectTypeFromEntDef(EntityDefinition ed) {
        if (ed.IsCustomSetting) {
            return ddCoreService.OBJECT_TYPE_CUSTOMSETTING;
        } else if (ed.QualifiedApiName.toLowerCase().right(5) ==  '__mdt') {
            return ddCoreService.OBJECT_TYPE_CUSTOMMETADATA;
        } else if (ed.QualifiedApiName.toLowerCase().right(3) ==  '__c' || ed.QualifiedApiName.toLowerCase().right(5) ==  '__kav') {
            // The __kav suffix is Knowledge, which is Salesforce internally considers to be a custom object
            return ddCoreService.OBJECT_TYPE_CUSTOMOBJECT;
        } else if (ed.QualifiedApiName.toLowerCase().right(3) ==  '__b') {
            return ddCoreService.OBJECT_TYPE_BIGOBJECT;
        // If you want to keep platform events in the Data Dictionary, uncomment these lines
        // } else if (ed.QualifiedApiName.toLowerCase().right(3) ==  '__e') {
        //     return ddCoreService.OBJECT_TYPE_PLATFORMEVENT;
        } else if (ed.QualifiedApiName.toLowerCase().right(3) ==  '__x') {
            return ddCoreService.OBJECT_TYPE_EXTERNALOBJECT;
        } else {
            return ddCoreService.OBJECT_TYPE_STANDARDOBJECT;
        }
    }

    public void createStubFromEntityDef(EntityDefinition ed) {
        this.setDurableId(ed.DurableId);
        this.fillFromEntityDefProvided(ed);
        this.ddo.Status__c = ddCoreService.OBJECT_STATUS_STUB;
    }

    public void fill() {
        this.fillFromDDO();
        this.fillFromEntityDef();
        if (this.ddo.Status__c == ddCoreService.OBJECT_STATUS_ACTIVE) {
            if (this.metadataUpdated || Test.isRunningTest()) {
                this.fillFromTooling();
            }
            this.fillRecordTypes();
            this.fillRecordCounts();           
            this.fillPageLayouts();
            this.fillPermissions();
        }
    }

    public void fillFromDDO() {
        // Get the Data Dictionary data
        List<Data_Dictionary_Object__c> ddoData = [
            SELECT Id, Name, API_Name__c, Durable_ID__c, Last_Processed__c, Prefix__c, Status__c, Type__c, Metadata_Created_by__c, Metadata_Created_Date__c, Metadata_Last_Modified_Date__c
            FROM Data_Dictionary_Object__c
            WHERE Id = :this.ddo.Id
        ];
        if (ddoData.size() == 1) {
            this.ddo = ddoData[0];
        }
    }

    public void fillFromTooling() {
        // Description, CreatedDate, CreatedBy -- all require tooling API
        this.ddo.Description__c = '';
        this.ddo.Metadata_Created_by__c = null;
        this.ddo.Metadata_Created_Date__c = null;                

        if (this.ddo.Type__c == ddCoreService.OBJECT_TYPE_CUSTOMOBJECT || this.ddo.Type__c == ddCoreService.OBJECT_TYPE_BIGOBJECT || this.ddo.Type__c == ddCoreService.OBJECT_TYPE_PLATFORMEVENT) {
            Map<String, Object> ToolingMap = GetCustomObjectToolingData(this.ddo.API_Name__c);

            if (ToolingMap.containsKey('Description')) {
                this.ddo.Description__c = (String)ToolingMap.get('Description');
            }
            if (ToolingMap.containsKey('CreatedDate')) {
                this.ddo.Metadata_Created_Date__c = Datetime.valueOfGmt(ddCoreService.formatDateTime((String)ToolingMap.get('CreatedDate')));
            }
            if (ToolingMap.containsKey('CreatedById')) {
                this.ddo.Metadata_Created_by__c = (String)ToolingMap.get('CreatedById');
            }
        }
    }

    public void fillFromEntityDefProvided(EntityDefinition ed) {
        if (ed == null) {
            if (ddo.Status__c == ddCoreService.OBJECT_STATUS_ACTIVE) {
                ddo.Status__c = ddCoreService.OBJECT_STATUS_DELETED;
                // TODO: clear other fields, like permissions?
            }
        } else {
            // Sync times
            if (this.ddo.Status__c == ddCoreService.OBJECT_STATUS_STUB) {
                this.ddo.First_Sync__c = Datetime.now();
                this.metadataUpdated = true;
            }
            this.ddo.Last_Processed__c = Datetime.now();

            // Basic info
            this.ddo.Status__c = ddCoreService.OBJECT_STATUS_ACTIVE;
            this.ddo.Name = ed.Label;
            this.ddo.API_Name__c = ed.QualifiedApiName;
            this.ddo.Prefix__c = ed.KeyPrefix;
            this.ddo.Namespace__c = ed.NamespacePrefix;
            this.ddo.Durable_ID__c = ed.DurableId;
            this.ddo.Type__c = GetObjectTypeFromEntDef(ed);

            // Last modified
            if (this.ddo.Metadata_Last_Modified_Date__c != ed.LastModifiedDate) {
                this.ddo.Metadata_Last_Modified_Date__c = ed.LastModifiedDate;
                this.metadataUpdated = true;
            }
            this.ddo.Metadata_Last_Modified_by__c = ed.LastModifiedById;
            
            // Sharing
            this.ddo.Internal_Sharing_Model__c = ed.InternalSharingModel;
            this.ddo.External_Sharing_Model__c = ed.ExternalSharingModel;
        }
    }

    public void fillFromEntityDef() {
        // Get any EntityDefinition data
        // TODO: Figure out DeploymentStatus
        List<EntityDefinition> entityData = [
            SELECT DeveloperName, DurableId, QualifiedApiName, IsCustomSetting, KeyPrefix, Label, LastModifiedById, LastModifiedDate, NamespacePrefix, PluralLabel, ExternalSharingModel, InternalSharingModel
            FROM EntityDefinition
            WHERE DurableId = :this.ddo.Durable_ID__c
        ];
        if (entityData.size() == 1) {
            this.fillFromEntityDefProvided(entityData[0]);
        } else {
            this.fillFromEntityDefProvided(null);
        }
    }

    public void fillRecordCounts() {
        // Total Record Count
        // TODO: check if this works for custom settings/metadata/etc.
        if (this.ddo.Type__c == ddCoreService.OBJECT_TYPE_STANDARDOBJECT || this.ddo.Type__c == ddCoreService.OBJECT_TYPE_CUSTOMOBJECT) {
            String countQuery = 'SELECT COUNT() FROM ' + this.ddo.API_Name__c;
            Integer recordCount = Database.countQuery(countQuery);
            this.ddo.Record_Count__c = recordCount;
        } else {
            this.ddo.Record_Count__c = null;
        }
    }

    public void fillPageLayouts() {
        List<String> pageLayoutList = ddCoreService.getPageLayoutNameListForObject(this.ddo.Durable_ID__c, this.ddo.API_Name__c, false);
        this.ddo.Page_Layouts__c = String.join(pageLayoutList, '\n');
    }

    public void fillRecordTypes() {
        String recordTypeNames = '';
        List<RecordType> rTypes = [
            SELECT Id, Name, DeveloperName, Description, IsActive, NamespacePrefix
            FROM RecordType
            WHERE SObjectType = :this.ddo.API_Name__c
            ORDER BY Name
        ];
        if (rTypes.size() > 0) {
            this.ddo.Has_Record_Types__c = true;
            // One dilemma here: if a record type is added by a namespaced package that has been set for
            // exclusion, do we include it here? I think we should, and so have; but if you feel otherwise,
            // you can add an exclusion here.
            for (RecordType rt : rTypes) {
                if (rt.IsActive) {
                    recordTypeNames = recordTypeNames + '\n' + rt.Name;
                }
            }
            this.ddo.Record_Types_Details__c = ddCoreService.longString(JSON.serializePretty(rTypes), 30000);
        } else {
            this.ddo.Has_Record_Types__c = false;
            this.ddo.Record_Types_Details__c = '';
        }
        this.ddo.Record_Types__c = recordTypeNames;
    }

    public void fillPermissions() {
        Map<Id, Profile> profilesMap = ddCoreService.getProfilesMap();
        Map<Id, PermissionSetGroup> permGroupsMap = ddCoreService.getPermGroupsMap();

        List<ObjectPermissions> objPerms = [
            SELECT Parent.Label, Parent.PermissionSetGroupId, Parent.ProfileId, Parent.IsCustom, PermissionsCreate, PermissionsRead, PermissionsEdit, PermissionsDelete, PermissionsModifyAllRecords, PermissionsViewAllRecords
            FROM ObjectPermissions 
            WHERE sObjectType = :this.ddo.API_Name__c
            ORDER BY Parent.Label
        ];

        // Permissions and profiles
        String objPermsCreate = '';
        String objPermsRead = '';
        String objPermsEdit = '';
        String objPermsDelete = '';
        String objPermsModAll = '';
        String objPermsViewAll = '';

        String objPermGroupsCreate = '';
        String objPermGroupsRead = '';
        String objPermGroupsEdit = '';
        String objPermGroupsDelete = '';
        String objPermGroupsModAll = '';
        String objPermGroupsViewAll = '';

        String objProfilesCreate = '';
        String objProfilesRead = '';
        String objProfilesEdit = '';
        String objProfilesDelete = '';
        String objProfilesModAll = '';
        String objProfilesViewAll = '';

        for (ObjectPermissions objPerm : objPerms) {
            if (objPerm.Parent.IsCustom && objPerm.Parent.ProfileID == null && objPerm.Parent.PermissionSetGroupId == null) {
                if (objPerm.PermissionsCreate) {
                    objPermsCreate += objPerm.Parent.Label + '\n';
                }
                if (objPerm.PermissionsRead) {
                    objPermsRead += objPerm.Parent.Label + '\n';
                }
                if (objPerm.PermissionsEdit) {
                    objPermsEdit += objPerm.Parent.Label + '\n';
                }
                if (objPerm.PermissionsDelete) {
                    objPermsDelete += objPerm.Parent.Label + '\n';
                }
                if (objPerm.PermissionsModifyAllRecords) {
                    objPermsModAll += objPerm.Parent.Label + '\n';
                }
                if (objPerm.PermissionsViewAllRecords) {
                    objPermsViewAll += objPerm.Parent.Label + '\n';
                }
            } else if (objPerm.Parent.PermissionSetGroupId != null) {
                String permGroupName = permGroupsMap.get(objPerm.Parent.PermissionSetGroupId).MasterLabel;
                if (objPerm.PermissionsCreate) {
                    objPermGroupsCreate += permGroupName + '\n';
                }
                if (objPerm.PermissionsRead) {
                    objPermGroupsRead += permGroupName + '\n';
                }
                if (objPerm.PermissionsEdit) {
                    objPermGroupsEdit += permGroupName + '\n';
                }
                if (objPerm.PermissionsDelete) {
                    objPermGroupsDelete += permGroupName + '\n';
                }
                if (objPerm.PermissionsModifyAllRecords) {
                    objPermGroupsModAll += permGroupName + '\n';
                }
                if (objPerm.PermissionsViewAllRecords) {
                    objPermGroupsViewAll += permGroupName + '\n';
                }
            } else if (objPerm.Parent.ProfileID != null) {
                String profileName = profilesMap.get(objPerm.Parent.ProfileID).Name;
                if (objPerm.PermissionsCreate) {
                    objProfilesCreate += profileName + '\n';
                }
                if (objPerm.PermissionsRead) {
                    objProfilesRead += profileName + '\n';
                }
                if (objPerm.PermissionsEdit) {
                    objProfilesEdit += profileName + '\n';
                }
                if (objPerm.PermissionsDelete) {
                    objProfilesDelete += profileName + '\n';
                }
                if (objPerm.PermissionsModifyAllRecords) {
                    objProfilesModAll += profileName + '\n';
                }
                if (objPerm.PermissionsViewAllRecords) {
                    objProfilesViewAll += profileName + '\n';
                }
            }

            objPerm = null;
        }

        Integer pMax = 20000;

        this.ddo.Permission_Sets_Create__c = ddCoreService.longString(objPermsCreate, pMax);
        this.ddo.Permission_Sets_Read__c = ddCoreService.longString(objPermsRead, pMax);
        this.ddo.Permission_Sets_Edit__c = ddCoreService.longString(objPermsEdit, pMax);
        this.ddo.Permission_Sets_Delete__c = ddCoreService.longString(objPermsDelete, pMax);
        this.ddo.Permission_Sets_View_All__c = ddCoreService.longString(objPermsViewAll, pMax);
        this.ddo.Permission_Sets_Modify_All__c = ddCoreService.longString(objPermsModAll, pMax);

        this.ddo.Permission_Set_Groups_Create__c = ddCoreService.longString(objPermGroupsCreate, pMax);
        this.ddo.Permission_Set_Groups_Read__c = ddCoreService.longString(objPermGroupsRead, pMax);
        this.ddo.Permission_Set_Groups_Edit__c = ddCoreService.longString(objPermGroupsEdit, pMax);
        this.ddo.Permission_Set_Groups_Delete__c = ddCoreService.longString(objPermGroupsDelete, pMax);
        this.ddo.Permission_Set_Groups_View_All__c = ddCoreService.longString(objPermGroupsViewAll, pMax);
        this.ddo.Permission_Set_Groups_Modify_All__c = ddCoreService.longString(objPermGroupsModAll, pMax);

        this.ddo.Profiles_Create__c = ddCoreService.longString(objProfilesCreate, pMax);
        this.ddo.Profiles_Read__c = ddCoreService.longString(objProfilesRead, pMax);
        this.ddo.Profiles_Edit__c = ddCoreService.longString(objProfilesEdit, pMax);
        this.ddo.Profiles_Delete__c = ddCoreService.longString(objProfilesDelete, pMax);
        this.ddo.Profiles_View_All__c = ddCoreService.longString(objProfilesViewAll, pMax);
        this.ddo.Profiles_Modify_All__c = ddCoreService.longString(objProfilesModAll, pMax);

        objPermsCreate = null;
        objPermsRead = null;
        objPermsEdit = null;
        objPermsDelete = null;
        objPermsModAll = null;
        objPermsViewAll = null;

        objPermGroupsCreate = null;
        objPermGroupsRead = null;
        objPermGroupsEdit = null;
        objPermGroupsDelete = null;
        objPermGroupsModAll = null;
        objPermGroupsViewAll = null;

        objProfilesCreate = null;
        objProfilesRead = null;
        objProfilesEdit = null;
        objProfilesDelete = null;
        objProfilesModAll = null;
        objProfilesViewAll = null;
    }

    public void save() {
        upsert ddo;
    }

}
