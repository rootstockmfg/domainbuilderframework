/**
 * Copyright 2019 
 * The Danville Group dba Rootstock Software
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software 
 * and associated documentation files (the "Software"), to deal in the Software without restriction, 
 * including without limitation the rights to use, copy, modify, merge, publish, distribute, 
 * sublicense, and/or sell copies of the Software, and to permit persons to whom the Software
 * is furnished to do so, subject to the following conditions:
 * 
 * - The above copyright notice and this permission notice shall be included in 
 *      all copies or substantial portions of the Software.
 * - Redistributions in binary form must reproduce the above copyright notice,
 *      this list of conditions and the following disclaimer in the documentation
 *      and/or other materials provided with the distribution.
 * - Neither the name of the Rootstock Software, The Danville Group, nor the names of its 
 *      contributors may be used to endorse or promote products derived from this software 
 *      without specific prior written permission.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
 * BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND 
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, 
 * DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

/**
 *  Domain Builder core implementation. Provides data mother & data factory functionality for easily
 *  controlling data creation for various use cases
 */
public inherited sharing virtual class dbf_DomainBuilder implements dbf_IDomainBuilder {

    // REGION START: STATIC PROPERTIES |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||

    /*
     * These static properties exist in application scope, and are not confined to a single builder.
     * This allows builders to populate these properties collectively, building a "stack" of data to
     * be committed or mocked at the very end. Executing .persist() or .mock() on any dbf_DomainBuilder
     * causes the entire "stack" to be persisted or mocked all at once.
     * Executing the static methods .persistAll() or .mockAll() accomplishes this same task, without
     * needing to have a local instantiation of dbf_DomainBuilder on hand.
     */

    /*
     *  provides a diagram which tells the system what order to process sObjects in the unit of work
     */
    private static dbf_DomainBuilderUoWGraph uowGraph = new dbf_DomainBuilderUoWGraph();

    /*
     *  provides a diagram which allows for dependency discovery of sobjects as values are assigned
     */
    private static dbf_DomainBuilderDiscGraph discGraph = new dbf_DomainBuilderDiscGraph();

    /*
     *  contains the list of builders which wrap builders from external, typically managed, packages
     *  data from these wrapped packages must be re-claimed before persist or mock is executed
    */
    private static List<dbf_IDomainBuilderReclaimableWrapper> wrappers = new List<dbf_IDomainBuilderReclaimableWrapper>();

    /*
     *  contains the list of builders that have been created and registered. IE: the data that will 
     *  ultimately be persisted or mocked
     */
    private static List<dbf_IDomainBuilder> registeredBuilders = new List<dbf_IDomainBuilder>();
    
    // REGION END: STATIC PROPERTIES |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||



    // REGION START: STATIC METHODS ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||

    /**
     * Executes the .persist() process on all currently registered domain builders
     *  @return         The resulting sObject of the 1st registered builder in the list
     */
    public static sObject persistAll() {
        if (registeredBuilders == null) { return null; }
        if (registeredBuilders.isEmpty()) { return null; }
        return registeredBuilders[0].persist();
    }

    /**
     *  Executes the .mock() process on all currently registered domain builders
     *  @return         A new mock data set containing data from all registered domain builders
     */
    public static dbf_IDomainBuilderMockDB mockAll() {
        if (registeredBuilders == null) { return new dbf_DomainBuilderMockDB(); }
        if (registeredBuilders.isEmpty()) { return new dbf_DomainBuilderMockDB(); }
        return registeredBuilders[0].mock();
    }

    // REGION END: STATIC METHODS ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||



    // REGION START: PUBLIC PROPERTIES |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||

    /**
     *  Retrieves the underlying sObject whose data is being constructed
     *  @return         An sObject representative of the original SObjectType, filled with supplied data
     */
    public sObject getRecord() { 
        reclaimSuspendedFieldValues();
        return record; 
    }

    /**
     *  Retrieves the underlying sObject's Id value
     *  @return         An Id from the underlying sObject, or null if none has been supplied yet
     */
    public Id getId() { return Id; }

    /**
     *  Retrieves the underlying sObject's SObjectType
     *  @return         The SObjectType of the underlying sObject
     */
    public SObjectType getType() { return type; }

    /**
     *  Descripes whether or not the SObject was created as a Setup Object or not
     *  @return         Boolean
     */
    public Boolean isSetupObject() { return setupObject; }
    
    // REGION END: PUBLIC PROPERTIES |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
    


    // REGION START: PRIVATE PROPERTIES ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
    
    /*
     *  stores whether or not the builder was created to handle a Setup object
     */
    private Boolean setupObject;

    /*
     *  lets the reclaim process know whether there is suspended data to reclaim or not
     */
    private Boolean hasUnclaimed = false;

    /**
     *  The sObject being populated with data and either persisted or mocked by this domain builder
     */
    protected SObject record;
    
    /**
     *  the Id value of the sObject built by this domain builder
     */
    protected Id id { private set; get {return record.Id;} }
    
    /**
     *  the sObject type of the sObject built by this domain builder
     */
    protected SObjectType type;

    /*
     *  list of parent domain builders who have had their assignment to a relationship field suspended until the moment of persist() or mock()
     */
    private Map<SObjectField, dbf_IDomainBuilder> s_parents = new Map<SObjectField, dbf_IDomainBuilder>();

    /*
     *  list of child domain builders who have had their assignment to a relationship field suspended until the moment of persist() or mock()
     */
    private Map<SObjectField, dbf_IDomainBuilder> s_children = new Map<SObjectField, dbf_IDomainBuilder>();

    /*
     *  list of external id referenced domain builders who have had their assignment to a relationship field suspended until the moment of persist() or mock()
     */
    private Set<dbf_DomainBuilderExtRef> s_externals = new Set<dbf_DomainBuilderExtRef>();

    /*
     *  suspended field-map style storage of all field-value pairs applied to .record
     *  used to re-serialize into a new sObject when field values are assigned or changed
     *  this allows the assignment of restricted field values when mocking
     */
    private Map<String, Object> s_record = new Map<String, Object>();

    /*
     *  a list of fields which have had their values set and are not restricted field types
     */
    private List<String> fields_unrestricted = new List<String>();

    /*
     *  a list of fields which have had their values attempted, but were denied due to field restrictions (such as formulas)
     */
    private List<String> fields_restricted = new List<String>();
    
    // REGION END: PRIVATE PROPERTIES ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||



    // REGION START: CONSTRUCTORS ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||

    public dbf_DomainBuilder(SObjectType type, Boolean isSetupObject) {
        this.type = type;
        this.record = type.newSObject(null, true);
        this.setupObject = isSetupObject;

        uowGraph.node(type);
        registeredBuilders.add(this);
    }

    public dbf_DomainBuilder(SObjectType type) {
        this(type, false);
    }
    
    // REGION END: CONSTRUCTORS ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||



    // REGION START: PUBLIC METHODS ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||

    /**
     *  Assigns the provided Field with the provided Value
     *  @param          fieldName   String      The field to be assigned a value
     *  @param          value       Object      The value to be assigned
     *  @return         The current Domain Builder
     */
    public dbf_IDomainBuilder set(String fieldName, Object value) {
        discGraph.registerForDiscovery(type, this, fieldName, value);
        
        applyFieldValue(fieldName, value);
        
        return (dbf_IDomainBuilder) this;
    }

    /**
     *  Assigns the provided Field with the provided Value
     *  @param          fieldName   SObjectField    The field to be assigned a value
     *  @param          value       Object          The value to be assigned
     *  @return         The current Domain Builder
     */
    public dbf_IDomainBuilder set(SObjectField field, Object value) {
        return set(field.getDescribe().getName(), value);
    }

    /**
     *  Persists all registered Domain Builders' sObjects to the Org, in order by UoW Graph
     *  @return         The sObject of the current Domain Builder
     */
    public virtual sObject persist() {
        if(invalidEnvironment()){ return null;} 
        reclaimData(true);
        discGraph.determinePreExisting();
        loadSuspendedRelationships();
        
	    fflib_SObjectUnitOfWork dataUow = unitOfWork();
	    fflib_SObjectUnitOfWork setupUow = unitOfWork();

        discGraph.prepareUoW(registeredBuilders, setupUow, dataUow);

        try {
            dataUow.commitWork();
        } catch (Exception ex) {
            System.Debug(ex);
            for(dbf_IDomainBuilder builder : registeredBuilders) {
                System.Debug('BUILDER <> <> <> <> <>');
                System.Debug(builder.getType());
                System.Debug(builder.getRecord());
            }
            throw ex;
        }

        if(Test.isRunningTest()) {
            System.runAs(new User(Id = UserInfo.getUserId())) {
                setupUow.commitWork();
            }
        }
        else {
            System.debug(LoggingLevel.ERROR, 'PermissionSetAssignment can not be inserted (Mixed DML)');
        }

	    dataUow = unitOfWork();
	    setupUow = unitOfWork();

        registeredBuilders.clear();

        return record;
    }
    
    /**
     *  Assigns the Developer Name to the current sObject
     *  @param          developerName   String  The collection in which to source RecordTypeId value
     *  @return         The current Domain Builder
     */
    public dbf_IDomainBuilder recordType(String developerName) {
        Id rtId = type.getDescribe().getRecordTypeInfosByDeveloperName().get(developerName).getRecordTypeId();
        return set('RecordTypeId', rtId);
    }
    
    /**
     *  Suspends, or shelves, the value for a Restricted, or Formula, field.
     *  Prevents DML errors, as restricted fields are NOT pushed to DML operations.
     *  Allows for retrieval of the suspended value in Mock usage.
     *  @param          fieldName   SObjectField    The field to be assigned a value
     *  @param          value       Object          The value to be assigned
     *  @return         The current Domain Builder
     */
    public dbf_IDomainBuilder assignRestrictedFieldValue(SObjectField field, Object value) {
        String fieldName = field.getDescribe().getName();
        s_record.put(fieldName, value);
        hasUnclaimed = true;
        if (!fields_restricted.contains(fieldName)) { fields_restricted.add(fieldName); }
        return this;
    }

    // REGION END: PUBLIC METHODS ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||



    // REGION START: PROTECTED METHODS |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||

    /**
     *  FOR IMPLEMENTATION USE ONLY, TO BE CALLED IN CONSTRUCTOR OF A WRAPPER OBJECT
     *  Registers an instance of a wrapped external builder for reclaimation of data on persist/mock
     *  @param          wrappedInstance dbf_IDomainBuilderReclaimableWrapper A builder which wraps an external package's builder
     *  @return         The same instance of dbf_IDomainBuilderReclaimableWrapper that was passed in, for fluent usability
     */
    protected virtual dbf_IDomainBuilder forExternal(dbf_IDomainBuilderReclaimableWrapper wrappedInstance) {
        wrappers.add(wrappedInstance);
        return this;
    }

    /**
     *  FOR INTERNAL USE ONLY
     *  Pulls data that was suspended, rather than being applied to the SObject
     *  straight away, and applies it to the SObject strategically.
     */
    protected void reclaimSuspendedFieldValues() {
        reclaimSuspendedFieldValues(false);
    }

    /**
     *  FOR INTERNAL USE ONLY
     *  Pulls data that was suspended, rather than being applied to the SObject
     *  straight away, and applies it to the SObject strategically.
     *  @param          Boolean, whether or not this is a DML operation.
     *                  This argument, when true, causes suspended values NOT to apply to restricted fields
     *                  This argument, when false, causes all values to be applied through JSON serialization,
     *                  including restricted fields.
     */
    protected void reclaimSuspendedFieldValues(Boolean for_dml) {
        // IF THIS IS A DML OPERATION, THEN PULL IN SUSPENDED VALUES AND ALSO REMOVE RESTRICTED VALUES
        if (for_dml) {
            reclaimSuspendedFieldValuesProtective();
            return;
        }

        if (!hasUnclaimed) { return; }

        // this should step around restrictions on fields
        // let formula fields, etc, fail at the dml level if persist() is called
        // allowing insert of restricted fields is supportive of mock()

        // deserialize record prop to keep track of type assignment
        Map<String, Object> fieldMap = (Map<String, Object>) JSON.deserializeUntyped( JSON.serialize( record ) );

        // assign values from the suspended record prop/map
        for(String field : s_record.keySet()) {
            fieldMap.put(field, s_record.get(field));
        }

        // re-serialize the record prop from the field value map
        record = (SObject) JSON.deserialize( JSON.serialize( fieldMap ), SObject.class );

        // mark all as claimed, so this operation doesn't repeat unnecessarily
        hasUnclaimed = false;
    }

    /**
     *  FOR INTERNAL USE ONLY
     *  Maps a parent relationship to the current Domain Builder
     */
    protected void doSetParent(SObjectField relationship, dbf_IDomainBuilder parent) {
        discGraph.setParent(this, relationship, parent);
        
        if(parent != null && !registeredBuilders.contains(parent)) {
            parent.registerIncludingParents();
        }

        uowGraph.edge(type, parent.getType());
    }

    /**
     *  FOR INTERNAL USE ONLY
     *  Maps this Domain Builder to a child as that child's parent
     */
    protected void doSetChild(SObjectField relationship, dbf_IDomainBuilder child) {
        if (child == null) { return; }
        discGraph.setParent(child, relationship, this);
        
        if(child != null && !registeredBuilders.contains(child)) {
            child.registerIncludingParents();
        }

        uowGraph.edge(child.getType(), type );
    }

    /**
     *  FOR INTERNAL USE ONLY
     *  Maps a reference Domain Builder by External ID field
     *  Provided in support for uow.registerRelationship(SObject record, Schema.sObjectField relatedToField
     *                                  , Schema.sObjectField externalIdField, Object externalId)
     */
    protected void doSetReference(SObjectField relatedToField, SObjectField targetExternalIdField, Object externalId) {
        SObjectType theRef = discGraph.setReference(this, relatedToField, targetExternalIdField, externalId);

        // add this relationship to the uow graph as if it were a parent relationship
        // this enforces order of operations in case the referenced object is being created as part of the stack
        uowGraph.edge(type, theRef);
    }


    /**
     *  FOR INTERNAL USE ONLY
     *  Gathers Parent, Child and External Id Reference objects that were suspended previously
     *  and assigns them to the local Domain Builder at the moment of persist() or mock().
     */
    protected void reclaimRelationships() {
        // handle suspended parent relationships
        if (!s_parents.isEmpty()) {
            for(SObjectField field : s_parents.keySet()) {
                doSetParent(field, s_parents.get(field));
            }
        }

        // handle suspended child relationships
        if (!s_children.isEmpty()) {
            for(SObjectField field : s_children.keySet()) {
                doSetChild(field, s_children.get(field));
            }
        }

        // handle suspended external relationships
        if (!s_externals.isEmpty()) {
            for(dbf_DomainBuilderExtRef ref : s_externals) {
                doSetReference(ref.getRelationshipField(), ref.getExternalIdField(), ref.getExternalId());
            }
        }
    }

    /**
     *  FOR INTERNAL USE ONLY
     *  Gathers wrapped sObject data and adds it to the local sObject via json serialization
     *  @param          target  dbf_DomainBuilder   The instance of dbf_DomainBuilder that the values should be assigned to
     *  @param          wrapped dbf_IDomainBuilderReclaimableWrapper    The wrapped external builder which contains the data
     */
    protected void reclaimData(dbf_IDomainBuilderReclaimableWrapper wrapped) {
        SObject source = wrapped.underlyingRecord();
        
        // Grab field values and insert them through registerForDiscovery static, in case there are fields being watched for discovery
        // Note:    This is necessary because when we wrap a domainbuilder we avoid the .set command, which handles this for us in a more concrete way.
        //     :    Since the registerForDiscovery method only executes when a field is being watched, it is safe to call for all fields without decision making.
        Map<String, Object> sourceValues = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(source));
        Map<String, Object> targetValues = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(record));
        for(String field : sourceValues.keySet()) {
            targetValues.put(field, sourceValues.get(field));
            registerDiscoverable(this, field, sourceValues.get(field));
        }

        record = (SObject) JSON.deserialize( JSON.serialize( targetValues ), SObject.class );
    }

    // REGION END: PROTECTED METHODS |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||



    // REGION START: PRIVATE METHODS |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||

    /*
     *  Prevents the data creation on invalid Environments such as Production orgs 
     *  and allows on other valid environments such as Sandboxes , Scratch orgs and Developer Editions.
     *  It also allows the execution while running unit tests in any environment. 
     *  @return         FALSE for Sandboxes, Scratch Orgs, Developer Editions and Unit tests.
     *                  TRUE for Production Orgs.
     */
    private static Boolean invalidEnvironment(){
        if(Test.isRunningTest()) { return FALSE; }
        List<Organization> lstOrgs = [SELECT Id, OrganizationType , isSandbox FROM 
                                     Organization];
        if(lstOrgs[0].isSandbox || lstOrgs[0].OrganizationType == 'Developer Edition'){
            return FALSE; 
        } 
        else {
            return TRUE;
        }
    }

    /*
     *  attempts to apply a supplied value to a supplied field
     *  if the application of the value fails then it is 
     */
    private void applyFieldValue(String field, Object value) {
        // this should step around restrictions on fields
        // let formula fields, etc, fail at the dml level if persist() is called
        // allowing insert of restricted fields is supportive of mock()

        Boolean wasSuspended = false;
        if (s_record == null) { s_record = new Map<String, Object>(); }

        try {
            if (fields_restricted.contains(field)) {
                // it's a suspension field, so assign it to the s_record
                s_record.put(field, value);
                wasSuspended = true;
            } else {
                // attempt to add it to the record
                record.put(field, value);
            }
        } catch (Exception ex) {
            // ignore the exception, because it means the field assignment was restricted... so suspend it for now
            s_record.put(field, value);
            wasSuspended = true;
        }

        if (wasSuspended) {
            // flag that there are unclaimed values
            hasUnclaimed = true;
            if (!fields_restricted.contains(field)) { fields_restricted.add(field); }
        } else {
            if (!fields_unrestricted.contains(field)) { fields_unrestricted.add(field); }
        }
    }

    /*
     *  reclaimation process for dml operations, IE: when .persist() is being executed
     *  protects restricted fields (formulas, etc) by removing any assigned values from them
     */
    private void reclaimSuspendedFieldValuesProtective() {
        Map<String, Object> protectedMap = new Map<String, Object>();
        Map<String, Object> fieldMap = (Map<String, Object>) JSON.deserializeUntyped( JSON.serialize( record ) );
        
        for(String field : fieldMap.keySet()) {
            if(fields_restricted.contains(field)) { continue; }
            protectedMap.put(field, fieldMap.get(field));
        }

        for(String field : s_record.keySet()) {
            if(fields_restricted.contains(field)) { continue; }
            protectedMap.put(field, s_record.get(field)); // should never be called, but just in case...
        }

        // re-serialize the record prop from the field value map
        record = (SObject) JSON.deserialize( JSON.serialize( protectedMap ), SObject.class );
         // flag that there are unclaimed values to false
        hasUnclaimed = false;
    }

    /*
     *  loads related object references that were suspended previously
     */
    private void loadSuspendedRelationships() {
        for(dbf_IDomainBuilder builder : registeredBuilders) {
            if (builder instanceOf dbf_DomainBuilder) {
                ((dbf_DomainBuilder)builder).reclaimRelationships();
            }
        }
    }

    /*
     *  overload for reclaimData(for_dml) which defaults to false
     */
    private void reclaimData() {
        reclaimData(false);
    }


    /*
     *  reassigns the local SObject to that of the underlyingBuilder. Pulls in suspended Parent, Child & External relationships
     */
    private void reclaimData(Boolean for_dml) {
        for(dbf_IDomainBuilder builder : registeredBuilders) {
            if (builder instanceOf dbf_DomainBuilder) {
                ((dbf_DomainBuilder)builder).reclaimSuspendedFieldValues(for_dml);
            }
        }

        for (dbf_IDomainBuilderReclaimableWrapper wrapper : wrappers) {
            dbf_IDomainBuilder myBuilder = wrapper.implementingBuilder();
            if (myBuilder instanceOf dbf_DomainBuilder) {
                ((dbf_DomainBuilder)myBuilder).reclaimData(wrapper);
            }
        }
    }

    /*
     *  generates a unit of work using the Graph
     */
    private static fflib_SObjectUnitOfWork unitOfWork() {
	    List<SObjectType> insertOrder = new List<SObjectType>();
	    List<SObjectType> sorted = uowGraph.sortTopologically();

	    for(Integer i = sorted.size() - 1; i >= 0; i--){
		    insertOrder.add(sorted[i]);
	    }
        return new fflib_SObjectUnitOfWork(insertOrder);
    }

    // REGION END: PRIVATE METHODS |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||



    // REGION START: MOCKING METHODS |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||

    /**
     *  Mocks all registered Domain Builders' sObjects to an instance of dbf_IDomainBuilderMockDB
     *  @return         The dbf_IDomainBuilderMockDB containing all sObjects generated
     */
    public virtual dbf_IDomainBuilderMockDB mock() {
        reclaimData();
        loadSuspendedRelationships();

        dbf_IDomainBuilderMockDB mockedData = new dbf_DomainBuilderMockDB()
            .usingBuilders(registeredBuilders)
            .generateIds()
            .generateRelationships(discGraph)
            .store();

        registeredBuilders.clear();

        return mockedData;
    }

    // REGION END: MOCKING METHODS |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||



    // REGION START: DISCOVERABLE SOBJECT METHODS ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||

    /**
     *  Registers a field & value in a particular Domain Builder as discoverable
     *  @param          target      dbf_IDomainBuilder  The builder on which the field & value are being applied
     *  @param          fieldName   String          The field that can be discovered
     *  @param          value       Object          The value being applied to the field
     *  @return         dbf_IDomainBuilder target that was passed in as an argument
     */
    public static dbf_IDomainBuilder registerForDiscovery(dbf_IDomainBuilder target, String fieldName, Object value) {
        discGraph.registerForDiscovery(target.getType(), target, fieldName, value);
        return target;
    }

    /**
     *  Finds an existing, registered Domain Builder parent, by field and value
     *  @param          targetType  SObjectType The Type of the SObject being searched for
     *  @param          targetField String      The field to be searched
     *  @param          targetValue Object      The value to be searched for
     *  @return         The discovered Domain Builder, or null
     */
    public static dbf_IDomainBuilder discoverRelationshipFor(SObjectType targetType, SObjectField targetField, Object targetValue) {
       return discGraph.discoverRelationshipFor(targetType, targetField, targetValue);
    }

    /**
     *  Finds an existing, registered Domain Builder parent, by field and value
     *  @param          target      dbf_IDomainBuilder  The Domain Builder to listed for discoveries
     *  @param          fieldName   String          The field to be listed
     *  @param          value       Object          The value to be listed
     *  @return         The discovered Domain Builder
     */
    public dbf_IDomainBuilder registerDiscoverable(dbf_IDomainBuilder target, String fieldName, Object value) {
        discGraph.registerForDiscovery(target.getType(), target, fieldName, value);
        return (dbf_IDomainBuilder) this;
    }

    /**
     *  Finds an existing, registered Domain Builder parent, by field and value
     *  @param          targetType  SObjectType     The Type of the SObject being searched for
     *  @param          targetField SObjectField    The field to be searched
     *  @param          targetValue Object          The value to be searched for
     *  @return         The discovered Domain Builder, or null
     */
    public dbf_IDomainBuilder discoverRelatedBuilder(SObjectType targetType, SObjectField targetField, Object targetValue) {
       return discGraph.discoverRelationshipFor(targetType, targetField, targetValue);
    }

    /**
     *  Maps a field on the current Domain Builder as one that can be discovered using discoverRelationshipFor()
     *  Causes set() operations to watch for the given field, and record the value/builder as a discoverable relationship 
     *    when that field has a value pushed to it.
     *  @param          targetType  SObjectType     The Type of the SObject being watched
     *  @param          targetField SObjectField    The field to be watched
     *  @return         The current Domain Builder
     */
    public static void mapDiscoverableField(SObjectType targetType, SObjectField field) {
        discGraph.setDiscoverableField(targetType, field);
    }

    /**
     *  Maps a field on the current Domain Builder as one that can be discovered using discoverRelationshipFor()
     *  Causes set() operations to watch for the given field, and record the value/builder as a discoverable relationship 
     *    when that field has a value pushed to it.
     *  @param          targetType  SObjectType     The Type of the SObject being watched
     *  @param          field       String          The field to be watched
     *  @return         The current Domain Builder
     */
    public void setDiscoverableField(SObjectType targetType, String field) {
        discGraph.setDiscoverableField(targetType, field);
    }

    /**
     *  Maps a field on the current Domain Builder as one that can be discovered using discoverRelationshipFor()
     *  Causes set() operations to watch for the given field, and record the value/builder as a discoverable relationship 
     *    when that field has a value pushed to it.
     *  @param          field       String          The field to be watched
     *  @return         The current Domain Builder
     */
    public void setDiscoverableField(String field) {
        discGraph.setDiscoverableField(type, field);
    }

    /**
     *  Maps a field on the current Domain Builder as one that can be discovered using discoverRelationshipFor()
     *  Causes set() operations to watch for the given field, and record the value/builder as a discoverable relationship 
     *    when that field has a value pushed to it.
     *  @param          targetType  SObjectType     The Type of the SObject being watched
     *  @param          targetField SObjectField    The field to be watched
     *  @return         The current Domain Builder
     */
    public void setDiscoverableField(SObjectType targetType, SObjectField field) {
        discGraph.setDiscoverableField(targetType, field);
    }

    /**
     *  Maps a field on the current Domain Builder as one that can be discovered using discoverRelationshipFor()
     *  Causes set() operations to watch for the given field, and record the value/builder as a discoverable relationship 
     *    when that field has a value pushed to it.
     *  @param          targetField     SObjectField    The field to be watched
     *  @return         The current Domain Builder
     */
    public void setDiscoverableField(SObjectField field) {
        discGraph.setDiscoverableField(type, field);
    }

    /**
     *  Assigns another dbf_IDomainBuilder as the current builder's parent
     *  @param          relationship    SObjectField        The field which refers to the parent
     *  @param          parent          dbf_IDomainBuilder  The builder to which a relationship should exist
     *  @return         The current Domain Builder
     */
    public virtual dbf_IDomainBuilder setParent(SObjectField relationship, dbf_IDomainBuilder parent) {
        s_parents.put(relationship, parent);
        return (dbf_IDomainBuilder) this;
    }

    /**
     *  Assigns another dbf_IDomainBuilder as the current builder's child
     *  @param          relationship    SObjectField        The field which refers to the parent
     *  @param          child           dbf_IDomainBuilder  The builder to which a relationship should exist
     *  @return         The current Domain Builder
     */
    public virtual dbf_IDomainBuilder setChild(SObjectField relationship, dbf_IDomainBuilder child) {
        s_children.put(relationship, child);
        return (dbf_IDomainBuilder) this;
    }

    /**
     *  Assigns an External ID reference to a another SObject for the given field
     *  @param          relatedToField          SObjectField    The field that should hold the relationship
     *  @param          targetExternalIdField   SObjectField    The target's External ID field
     *  @param          externalId              Object          The value that should exist in the targetted SObject's External ID field
     *  @return         The current Domain Builder
     */
    public virtual dbf_IDomainBuilder setReference(SObjectField relatedToField, SObjectField targetExternalIdField, Object externalId) {
        s_externals.add(new dbf_DomainBuilderExtRef()
            .withRelationshipField(relatedToField)
            .targettingExternalIdField(targetExternalIdField)
            .forValue(externalId));
        return (dbf_IDomainBuilder) this;
    }

    /**
     *  Registers the current comain builder and its upstream.
     *  @return         The current Domain Builder
     */
    public dbf_IDomainBuilder registerIncludingParents() {
        if(record.Id == null) {
            registeredBuilders.add(this);

            discGraph.registerParents(this);
        }
        return this;
    }

    /**
     *  Removes the current Domain Builder from the list of registered builders, including upstream relationships
     */
    public void unregisterIncludingParents() {
        registeredBuilders.remove(registeredBuilders.indexOf(this));

        discGraph.unregisterParents(this);
    }

    /**
     *  Synchronizes changes on one field with another field
     */
    public void syncOnChange(SObjectField sourceField, dbf_IDomainBuilder targetObject, SObjectField targetField) {
        discGraph.syncOnChange(this, sourceField, targetObject, targetField);
    }

    // REGION END: DISCOVERABLE SOBJECT METHODS ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
}