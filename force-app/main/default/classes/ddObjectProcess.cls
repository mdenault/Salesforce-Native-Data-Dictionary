/*

This is the first class/method called when doing a full Data Dictionary population.
What we ae doing here is making sure the basic list of Data Dictionary object records is populated with the most up to date
list of objects possible.
We will then iterate over each of those DDO objects in the ddObjectProcessBatch class, and then iterate over each of their
fields in the ddFieldProcessBatch class.

*/
public with sharing class ddObjectProcess implements System.Schedulable {

    public void execute(SchedulableContext cx) {
        execute();
    }

    public void execute() {
        List<Data_Dictionary_Object__c> newDataObjects = new List<Data_Dictionary_Object__c>();

        // Get the raw list of all Entity Definitions
        List<EntityDefinition> entDefList = getRawEntityDefList();

        // Filter out the ones we don't want
        entDefList = filterEntDefList(entDefList);

        // Get a list of existing Data Dictionary Objects, to compare/contrast with
        List<String> ddoDurableIds = getDDODurableIds();

        // Check to see if there are any Draft objects
        List<Data_Dictionary_Object__c> draftObjs = [
            SELECT Id, API_Name__c
            FROM Data_Dictionary_Object__c
            WHERE Status__c = :ddCoreService.OBJECT_STATUS_DRAFT
        ];

        // Create DDO records for any new Objects, or promote Draft records to Active
        for (EntityDefinition entDef : entDefList) {
            if (ddoDurableIds.contains(entDef.DurableId) == false) {
                ddObject ddoSetup = new ddObject();
                ddoSetup.createStubFromEntityDef(entDef);
                if (draftObjs.size() > 0) {
                    for (Data_Dictionary_Object__c draftObj : draftObjs) {
                        if (draftObj.API_Name__c == entDef.QualifiedApiName) {
                            ddoSetup.setId(draftObj.Id);
                            break;
                        }
                    }
                }
                Data_Dictionary_Object__c ddoNew = ddoSetup.getDDO();
                newDataObjects.add(ddoNew);
            }
        }
        if (newDataObjects.size() > 0) {
            upsert newDataObjects;
        }

        // Call our batch to process these Data Dictionary Objects
        if (Test.isRunningTest() == false) {
            ddObjectProcessBatch ddob = new ddObjectProcessBatch();
            Database.executeBatch(ddob, 1);
        }
    }

    public static List<String> getDDODurableIds() {
        List<String> ddoDurableIds = new List<String>();
        List<Data_Dictionary_Object__c> ddoList = [
            SELECT Id, Durable_Id__c
            FROM Data_Dictionary_Object__c
        ];
        for (Data_Dictionary_Object__c ddo : ddoList) {
            ddoDurableIds.add(ddo.Durable_ID__c);
        }
        return ddoDurableIds;
    }

    public static List<EntityDefinition> filterEntDefList(List<EntityDefinition> entDefs) {
        List<EntityDefinition> returnList = new List<EntityDefinition>();

        Data_Dictionary_Setting__mdt settings = ddCoreService.getActiveSettings();

        List<String> includeStandardObj = ddCoreService.lowercaseList(ddCoreService.getListFromSetting('Standard_Objects_to_Include__c', settings));
        List<String> includeCustomObj = ddCoreService.lowercaseList(ddCoreService.getListFromSetting('Custom_Objects_to_Include__c', settings));
        List<String> excludeCustomObj = ddCoreService.lowercaseList(ddCoreService.getListFromSetting('Custom_Objects_to_Exclude__c', settings));
        List<String> includeCustomMeta = ddCoreService.lowercaseList(ddCoreService.getListFromSetting('Custom_Metadata_Types_to_Include__c', settings));
        List<String> includeCustomSettings = ddCoreService.lowercaseList(ddCoreService.getListFromSetting('Custom_Settings_to_Include__c', settings));
        List<String> excludeCustomObjNamespaces = ddCoreService.lowercaseList(ddCoreService.getListFromSetting('Namespaces_to_Exclude__c', settings));

        for (EntityDefinition entDef: entDefs) {
            String lcApiName = entDef.QualifiedApiName.toLowerCase();
            // It makes the "if" conditions below significantly simpler if we have a fake namespace, because otherwise
            // we have to worry about a null namespace actually being found in a null list of namespace exclusions.
            String lcNamespace = 'This Is Not A Real Namespace';
            if (String.isNotEmpty(entDef.NamespacePrefix)) {
                lcNamespace = entDef.NamespacePrefix.toLowerCase();
            }

            // Standard objects -- only include those specifically listed
            if (includeStandardObj.contains(lcApiName)) {
                returnList.add(entDef);
            }

            // Custom objects, including big objects and external objects -- include by default unless excluded explicitly or by namespace
            if (entDef.IsCustomSetting == false && (lcApiName.right(3) ==  '__c' || lcApiName.right(3) ==  '__b' || lcApiName.right(3) ==  '__x' || lcApiName.right(5) ==  '__kav')) {
                if (includeCustomObj.contains(lcApiName) || (excludeCustomObjNamespaces.contains(lcNamespace) == false && excludeCustomObj.contains(lcApiName) == false)) {
                    returnList.add(entDef);
                }
            }

            // Custom settings -- include by default except excluded namespaces, or include only those listed
            if (entDef.IsCustomSetting == true && ((includeCustomSettings.isEmpty() && excludeCustomObjNamespaces.contains(lcNamespace) == false) || includeCustomSettings.contains(lcApiName))) {
                returnList.add(entDef);
            }

            // Custom metadata types -- include by default except excluded namespaces, or include only those listed
            if (lcApiName.right(5) ==  '__mdt' && ((includeCustomMeta.isEmpty() && excludeCustomObjNamespaces.contains(lcNamespace) == false) || includeCustomMeta.contains(lcApiName))) {
                returnList.add(entDef);
            }

            // TODO: Consider adding platform events--just not sure if they fit the remit of this app
        }

        return returnList;
    }

    public static List<EntityDefinition> getRawEntityDefList() {
        Set<EntityDefinition> returnSet = new Set<EntityDefinition>();
        Boolean done = false;
        String lastObject = '';

        // EntityDefinition doesn't support QueryMore so a maximum of 200 can be returned per query.
        // We also have the concern that the maximum offet allowed by SOQL is 2000 but the maximum
        // number of custom objects is 3000. So we can't just use a numeric offset here, instead we
        // need to use a dynamic WHERE clause to chunk the entities safely.
        while (done == false) {
            String query = 'SELECT DurableId, DeveloperName, IsCustomSetting, KeyPrefix, NamespacePrefix, Label, QualifiedApiName, LastModifiedById, LastModifiedDate, PluralLabel, InternalSharingModel, ExternalSharingModel';
            query += ' FROM EntityDefinition';
            if (String.isNotEmpty(lastObject)) {
                query += ' WHERE DurableId > \'' + lastObject + '\'';
            }
            query += ' ORDER BY DurableId ASC';
            query += ' LIMIT 200';

            List<EntityDefinition> entDefs = Database.query(query);
            Integer retSize = entDefs.size();
            if (retSize > 0) {
                returnSet.addAll(entDefs);
                if (retSize == 200) {
                    lastObject = entDefs[199].DurableId;
                }
            }

            if (retSize < 200) {
                done = true;
            }
        }

        return new List<EntityDefinition>(returnSet);
    }

}
