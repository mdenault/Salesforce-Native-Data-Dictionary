# Salesforce Native Data Dictionary

This is a tool to create a data dictionary of objects and fields within Salesforce, to assist with data governance efforts.

At each of organizations I have worked at that used Salesforce, there was a need for a data dictionary--a list of objects and fields, with information such as data types and descriptions of the intended use. Frequently some attempt was made to use speadsheets to record this information, with all the attendant problems: information quickly getting out of date, multiple versions, etc.

This is ironic given how Salesforce often starts in an organization as a replacement for spreadsheets, and how metadata-centric it is. And while I know there are existing solutions ranging from Elements Cloud to Bob Buzzard's Org Documetor, they have disadvantags such as cost, security, and being off-platform. The on-platform solutions I found, such as Metadata Dictionary and FieldPro, tend to be positioned solely as tools for an admin's own use. I saw benefts in having an on-platform, general-purpose data dictionary; so as a weekend project, I built this Salesforce Native Data Dictionary.

## What It Does

- Defines three custom objects: Data Dictionary Objects, Data Dictionary Fields, and Data Dictionary Change Logs.
- Provides automation to populate each (via a scheduled batch job, plus triggers to create the Change Logs).
- Data Dictionary Fields includes information for each field such as its Label, API name, data type, both description and help text, default value, any defined ownership and data compliance information, the complete set of active values for picklist fields, and lists of the page layouts that display the field, and the profiles/permission sets/permission set groups that provide read and edit access to the field.
- Optionally, a secondary job will calculate what percentage of records that have data for each field, for each record type of the object.
- Data Dictionary Object likewise 
- If an object or field is deleted, both Data Dictionary Object and Data Dictionary Field have a "Status" field that will be automatically changed from "Active" to "Deleted."
- Data Dictionay Change Logs captures changes to any of the above, extending Salesforce's built-in field history tracking by capturing before/after changes a) for more than just 20 fields per object, b) retaining change data for more than just 18 months, and c) storing full before/after information for all elements of the Dictionary, including the long text data needed to store lists of permissions, picklist values, and the like.
- You can control which standard and custom objects are included in the Dictionary, as well as various other options, declaratively through custom metadata.

By building all this natively on platform, we get a number of advantages:

- It's all in Salesforce--you and your users already know where it is and how to use it.
- Because they're just custom objects, you can grant access to all or part of the Data Dictionary to your users via profiles, permission sets, and sharing rules.
- You can customize how it is displayed with page layouts and the new Dynamic Forms. Include only the parts you need. Extend it with a Files tab for supplementary data, or Chatter to permit discussions, etc.
- You can add your own custom fields to these objects to capture information specific to your org. We use Marketing Cloud at my current job, so maybe we'd add a "Synced to Marketing Cloud" checkbox field to the Data Dictionary Fields object, to help us remember which fields are used there. (Fields you add must be manually populated, of course, but data updates to them can be captured in the Change Logs if you like.)
- In my current org, we use the standard Case object for users to request changes such as new picklist values, and Knowledge to record business process information. It's handy to be able to add lookups on these objects to the Data Dictionary objects, or to create new junction objects--to see for example all the Cases that have led to updates of a certain field.
- As noted above, because each entry is just a record in Salesforce, if an object or field is deleted, we can label the entry as deleted but otherwise persist the data, providing a durable record of changes over time.
- You can report on this data using Salesforce native reporting. It's very easy to create a report of all fields with their descriptions and help text for a certain object; or all fields with data owned by a certain user or public group; or all fields accesible to a certain Permission Set Group; or all field permission changes in the last two days; or anything else you can do with report filters.
- And to bring things full circle, of course you can export this data to Excel from Salesforce reports.

Andyou can extend all of this even further using all the tools available to you on the Salesforce platform, declaratively or with code.

## Installation

<a href="https://githubsfdeploy.herokuapp.com">
  <img alt="Deploy to Salesforce"
       src="https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/deploy.png">
</a>

The `sfdx-project.json` file contains useful configuration information for your project. See [Salesforce DX Project Configuration](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_ws_config.htm) in the _Salesforce DX Developer Guide_ for details about this file.

## Known Limitations and Issues

- [Salesforce Extensions Documentation](https://developer.salesforce.com/tools/vscode/)
- [Salesforce CLI Setup Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_intro.htm)
- [Salesforce DX Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_intro.htm)
- [Salesforce CLI Command Reference](https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/cli_reference.htm)
