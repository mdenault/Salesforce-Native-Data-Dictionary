# Salesforce Native Data Dictionary

This is a tool to create a data dictionary of objects and fields within Salesforce, to assist with data governance efforts.

At each of organizations I have worked at that used Salesforce, there was a need for a data dictionary--a list of objects and fields, with information such as data types and descriptions of the intended use. Frequently some attempt was made to use speadsheets to record this information, with all the attendant problems: information quickly getting out of date, multiple versions, etc.

This is ironic given how Salesforce often starts in an organization as a replacement for spreadsheets, and how metadata-centric it is. And while there are existing solutions ranging from Elements Cloud to [Bob Buzzard's Org Documentor](https://bobbuzzard.blogspot.com/p/org-documentor.html), they have disadvantags such as cost, security, and being off-platform. The on-platform solutions I found, such as [Metadata Dictionary](https://github.com/jongpie/SalesforceMetadataDictionary), tend to be positioned as tools for an admin's own exclusive use. I saw benefts in having an on-platform, general-purpose data dictionary; so as a weekend project, I built this **Salesforce Native Data Dictionary**.

## What It Does

- Defines three custom objects: Data Dictionary Object, Data Dictionary Field, and Data Dictionary Change Log.
- Provides automation to populate each (via a scheduled batch job, plus triggers to create the Change Logs).
- **Data Dictionary Field** includes information for each field such as its Label, API name, data type, both description and help text, default value, any defined ownership and data compliance information, the complete set of active values for picklist fields, and lists of the page layouts that display the field, and the profiles/permission sets/permission set groups that provide read and edit access to the field.
- Optionally, a secondary job will calculate what percentage of records that have data for each field, for each record type of the object.
- **Data Dictionary Object** likewise 
- If an object or field is deleted, both Data Dictionary Object and Data Dictionary Field have a "Status" field that will be automatically changed from "Active" to "Deleted."
- **Data Dictionary Change Logs** captures changes to any of the above, extending Salesforce's built-in field history tracking by capturing before/after changes a) for more than just 20 fields per object, b) retaining change data for more than just 18 months, and c) storing full before/after information for all elements of the Dictionary, including the long text data needed to store lists of permissions, picklist values, and the like.
- You can control which standard and custom objects are included in the Dictionary, as well as various other options, declaratively through custom metadata.

By building all this natively on platform, we get a number of advantages:

- It's all in Salesforce--you and your users already know where it is and how to use it.
- Because they're just custom objects, you can grant access to all or part of the Data Dictionary to your users via profiles, permission sets, and sharing rules.
- You can add your own custom fields to these objects to capture information specific to your org. Fields you add must be manually populated, of course, but data updates to them can be captured in the Change Logs if you like.
- Easy to link to standard objects such as Cases and Knowledge.
- If an object or field is deleted, we can label its entry in the Dictionary as deleted but otherwise persist the data, providing a durable record of changes over time.
- You can customize how the Dictionary is displayed using normal Salesforce tools like page layouts and Dynamic Forms. Include only the parts you need. Extend it with a Files tab for supplementary data, or Chatter to permit discussions, etc.
- You can report on this data using Salesforce native reporting. It's very easy to create a report of all fields with their descriptions and help text for a certain object; or all fields with data owned by a certain user or public group; or all fields accesible to a certain Permission Set Group; or all field permission changes in the last two days; or anything else you can do with report filters.
- To bring things full circle, of course you can export this data to Excel from Salesforce reports.

And you can extend all of this even further using all the tools available to you on the Salesforce platform, declaratively or with code.

It's important to note that from an auditing perspective, 

## Installation

The tool is designed to be installed by a system administrator.

### Deploy

Deploy to a sandbox first and test the below steps there. In fact, because the actual data in the org is largely irrelevant to this tool, I'd suggest creating a sandbox just for testing this tool, if your licenses permit that.

<a href="https://githubsfdeploy.herokuapp.com">
  <img alt="Deploy to Salesforce"
       src="https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/deploy.png">
</a>

(Indeed, there may be some situations where all you ever need to do is install this in a sandbox.)

### Configure your desired options in the "Data Dictionary Settings" Custom Metadata

In the Custom Metadata Types section of Setup, find the "Data Dictionary Settings" entry and click "Manage." The entry labeled "Active" is the one the tool uses.

The main changes you will want to make here are what objects to include or exclude in the Data Dictionary. The settings are as follows:

- **Standard Objects** must be listed (by API Name) to be included. A selection of the most common are listed by default.
- **Custom Objects, including Big Objects and External Objects** are included by default, unless they are 1) listed in "Custom Objects to Exclude" or 2) part of a namespace listed in "Namespaces to Exclude" and not explicitly listed in "Custom Objects to Include."
- **Custom Settings and Custom Metadata Types** are excluded by default, and must be listed to be included.

The other settings here deal with system fields to exclude from the Dictionary, and internal fields on the Data Dictionary Object and Field objects that should not trigger Change Log entries.

### Assign permissions

The project comes with two permission sets, "Data Dictionary - Read Only" and "Data Dictionary - Modify All". 

### Do a test run

Depending on the complexity of your org, and how busy it and its infrastructure are at the moment, a run of the tool to populate data can take anywhere from 10 minutes to several hours.

Initiate a test run by opening the Developer Console and executing the following anonymous Apex:

```
ddObjectProcess ddproc = new ddObjectProcess();
ddproc.execute();
```
This will initiate a sequential series of jobs to populate the Data Dictionary (see "Architecture" below).

I would suggest doing at least one and if possible several test runs to verify:

1. Does population complete successfully, and are the settings to your liking?
2. How long does it take?

Once you have those answers, you can schedule the sync updates.

### Set the schedule

If you want the sync to update once per day, which is what I'd recommend for most orgs, you can do that through the UI.

## Architecture

1. ddObjectProcess runs first. It fetches a list of objects in the org and creates "stub" entries in Data Dictionary Object for those matching criteria for inclusion. It then begins the ddObjectProcessBatch batch class.
  - Processing happens all at once, in a single pass.
2. ddObjectProcessBatch fills in the gaps in the stub Data Dictionary Object records, adding lists of permissions, page layouts, record types, etc. When it is done, it then begins the ddFieldProcessBatch batch class.
  - Processing happens one object per batch.
3. ddFieldProcessBatch cycles through each Data Dictionary Object, retrieves the fields for that object, and in a series of passes fills in the field details. It then calls ddFieldDetailsBatch.
  - Processing happens one object per batch, but the batch class chains to itself several times to fill in different sets of information.
4. ddFieldDetailsBatch cycles through different sets of the created fields to calculate additional per-field information such as usage by recordtype.
  - Processing happens in groups of fields; again, the batch class chains to itself several times to fill in different sets of information.

So the basic pattern is, create the basics quickly, and then fill in the details over separate passes. This approach proved advisable during initial testing to mitigate issues such as CPU timeouts and heap limit overages.

The information gathered comes from a variety of sources: the internal EntityDefinition and FieldDefinition objects, Describe calls, the native Apex Metadata API wrapper, and calls to the Tooling and User Interface APIs. While I make no claim to have combined these artfully, the main value I feel I'm providing here is working out what information lives where and how to get it all in one place.

## Contributing

I'd be happy to receive both issue reports and pull requests. This was a weekend/pandemic learning project for me, so the code definitely could use a refactor, and I'm not in a position where I can test very large object/field counts, external objects, and various other features. So while I have everything working in my test orgs, part of the reason for putting this out there is to see what issues arise, and from that determine what aspects of the architecture may need to change.

As far as feature contributions, I would be very interested to see what people may find useful for their own governance needs. Just note that it's easy to imagine scope creep in a tool like this. I do want to keep it focused on data governance needs--an aid to creating and sustaining a technically literate population of users interested in maintaining the health of their org.

## Known Limitations, Issues, and To Do

- Information such as the Page Layouts that a field is found on, or Permission Sets that grant access to it, are stored as simple lists of names. Thus, simply renaming one of these will be interpreted as a change, and Change Log records will be generated for all impacted objects and fields.

- It can show which Page Layout a field is included on, but it cannot yet list the Lightning Record Pages where the field is included using the new Dynamic Forms system.

- Can't list out the custom criteria-based sharing rules you've created for objects.

- Some data isn't currently pulled for Big Objects 

### To Do

- Picklist values by record type
- Consider adopting the Metadata Wrapper
- Consider separae objects for user/perm sets/groups/profiles?
	- would allow tracking of things like "modify all data"
- Consider separate object for validation rules to allow tracking changes to their details

## License

