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
        System.debug('entDefList size 1 = ' + entDefList.size());

        // Filter out the ones we don't want
        entDefList = filterEntDefList(entDefList);
        System.debug('entDefList size 2 = ' + entDefList.size());

        // Get a list of existing Data Dictionary Objects, to compare/contrast with
        List<String> ddoDurableIds = getDDODurableIds();

        // Create DDO records for any new Objects, or promote Draft records to Active
        for (EntityDefinition entDef : entDefList) {
            if (ddoDurableIds.contains(entDef.DurableId) == false) {
                ddObject ddoSetup = new ddObject();
                ddoSetup.CreateStubFromEntityDef(entDef);
                Data_Dictionary_Object__c ddoNew = ddoSetup.GetDDO();
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

        List<String> includeStandardObj = ddCoreService.getListFromSetting('Standard_Objects_to_Include__c', settings);
        List<String> includeCustomObj = ddCoreService.getListFromSetting('Custom_Objects_to_Include__c', settings);
        List<String> excludeCustomObj = ddCoreService.getListFromSetting('Custom_Objects_to_Exclude__c', settings);
        List<String> includeCustomMeta = ddCoreService.getListFromSetting('Custom_Metadata_Types_to_Include__c', settings);

        for (EntityDefinition entDef: entDefs) {
            // First the basics -- weed out the standard objects we definitely don't want
            if ((!entDef.QualifiedApiName.containsIgnoreCase('history') && !entDef.QualifiedApiName.containsIgnoreCase('tag') && !entDef.QualifiedApiName.containsIgnoreCase('share') && !entDef.QualifiedApiName.containsIgnoreCase('feed')) || entDef.QualifiedApiName.toLowerCase().right(3) ==  '__c') {
                // Now check our list of includes and excludes
                // TODO: need to account better for custom settings, metadata, platform events, etc.
                if ((includeStandardObj.isEmpty() && entDef.QualifiedApiName.toLowerCase().right(3) !=  '__c') || includeStandardObj.contains(entDef.QualifiedApiName)) {
                    returnList.add(entDef);
                }
                if ((includeCustomObj.isEmpty() && entDef.QualifiedApiName.toLowerCase().right(3) ==  '__c') || includeCustomObj.contains(entDef.QualifiedApiName)) {
                    returnList.add(entDef);
                }
                if ((includeCustomObj.isEmpty() && entDef.QualifiedApiName.toLowerCase().right(3) ==  '__b')) {
                    returnList.add(entDef);
                }
                if ((includeCustomObj.isEmpty() && entDef.QualifiedApiName.toLowerCase().right(3) ==  '__e')) {
                    returnList.add(entDef);
                }
                if ((includeCustomMeta.isEmpty() && entDef.QualifiedApiName.toLowerCase().right(5) ==  '__mdt') || includeCustomMeta.contains(entDef.QualifiedApiName)) {
                    returnList.add(entDef);
                }
            }
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
        // need to sort and use a dynamic WHERE clause to chunk the entities safely.
        while (done == false) {
            String query = 'SELECT DurableId, DeveloperName, IsCustomSetting, KeyPrefix, NamespacePrefix, Label, QualifiedApiName, LastModifiedById, LastModifiedDate, PluralLabel, InternalSharingModel, ExternalSharingModel';
            query += ' FROM EntityDefinition';
            if (String.isNotEmpty(lastObject)) {
                query += ' WHERE DurableId > \'' + lastObject + '\'';
            }
            query += ' ORDER BY DurableId ASC';
            query += ' LIMIT 200';

            System.debug(query);

            List<EntityDefinition> entDefs = Database.query(query);
            Integer retSize = entDefs.size();
            System.debug('Return size = ' + String.valueOf(retSize));
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
