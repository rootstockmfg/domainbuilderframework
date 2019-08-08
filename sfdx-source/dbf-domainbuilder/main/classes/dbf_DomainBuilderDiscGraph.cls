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
 *  Domain Builder Discovery Graph. Assists Domain Builder in tracking, identifying and resolving 
 *  dependencies between Domain Builders that reference one another via setParent, setChild or 
 *  setReference.
 *  As builders are created, setDiscoverableField can be called in the constructor.
 *  Setting a field as discoverable, adds it to collections in this Discovery Graph to be watched. 
 *  As values are assigned to watched fields, the values are recorded into a collection here. 
 *  When a builder, or more specifically a Narrative, later attempts to relate to another builder it can call one of many
 *    methods to do so. All of them cause a search to occur across the maps & collections in Discovery Graph. 
 *  Once a builder is discovered through the use of these maps, it is returned to be the relationship target. 
 *  Watched, or discoverable, fields are also used to run SOQL against the org before persisting data. If data is found in the
 *    org which matches the values being assigned to these fields, the ID is retrieved and assigned to the builder(s) and their
 *    commit process shifts to an update rather than an insert. 
 *  Therefore, so long as discoverable fields are assigned appropriately builders can safely be executed multiple times against
 *    an org without collisions. 
 */
public with sharing class dbf_DomainBuilderDiscGraph {

    /**
     *  contains a list of fields, by sObject type, that should be watched for discovery of parent objects by children
     */
    private Map<SObjectType, List<String>> discoverableFields = new Map<SObjectType, List<String>>();

    /**
     *  contains the list of discoverables by Key. Key is comprised of sObject type, sObject field and value
     *  discoveries can be found by children statically, using discoverRelationshipFor() below
     */
    private Map<String, dbf_IDomainBuilder> discoveries = new Map<String, dbf_IDomainBuilder>();
    
    /**
     *  contains a map of fields being watched for discovery, by object type key
     */
    private Map<String, String> discoveryFields = new Map<String, String>();
    
    /**
     *  Map of sOjbects which contain a map of sKey's and the API Field names for each discovered sObject type.
     */
    private Map<SObjectType, Map<String, List<String>>> discoveryFieldsByObjectType = new Map<SObjectType, Map<String, List<String> >>();
    
    /**
     *  contains a map of values being tracked for discovery, by object type name & field name key
     */
    private Map<String, List<Object>> discoveryValues = new Map<String, List<Object>>();
  
    /**
     *  contains the parent relationship mappings for this builder, used to give process order in the unit of work
     */
    private Map<dbf_IDomainBuilder, Map<SObjectField, dbf_IDomainBuilder>> parentByRelationship = new Map<dbf_IDomainBuilder, Map<SObjectField, dbf_IDomainBuilder>>();

    /**
     *  contains a collection of dbf_DomainBuilderExtRef, which helps map references by External ID flagged fields
     */
    private Map<dbf_IDomainBuilder, Set<dbf_DomainBuilderExtRef>> externalIdReferences = new Map<dbf_IDomainBuilder, Set<dbf_DomainBuilderExtRef>>();

    /**
     *  contains a map of related sObject fields that should be syncronozed across multiple domain builder instances
     */
    private Map<dbf_IDomainBuilder, Map<SObjectField, Map<SObjectField, List<dbf_IDomainBuilder>>>> relationshipsToSync
        = new Map<dbf_IDomainBuilder,  Map<SObjectField, Map<SObjectField, List<dbf_IDomainBuilder>>>>();

    /**
     *  Retrieves the parent relationship map for a given child
     *  @param      source  dbf_IDomainBuilder  The child to find all parent relationships for
     *  @return     A map of parent relationships
     */ 
    public Map<SObjectField, dbf_IDomainBuilder> getParentRelationMap(dbf_IDomainBuilder source) {
        return parentByRelationship.get(source);
    }

    /**
     *  Retrieves the external id relationship map for a given child
     *  @param      source  dbf_IDomainBuilder  The builder to find all External ID relationships for
     *  @return     A set of dbf_DomainBuilderExtRef objects
     */ 
    public Set<dbf_DomainBuilderExtRef> getExternalReferences(dbf_IDomainBuilder source) {
        return externalIdReferences.get(source);
    }


    public dbf_DomainBuilderDiscGraph() {
        discoverableFields = new Map<SObjectType, List<String>>();
        discoveries = new Map<String, dbf_IDomainBuilder>();
        discoveryFields = new Map<String, String>();
        discoveryValues = new Map<String, List<Object>>();
        discoveryFieldsByObjectType = new  Map<SObjectType, Map<String, List<String>>>();
    }
    
    /**
     *  Checks against the Org to see if any records exist with the builder's discoverable fields.
     *  If a record exists the Id is saved to the builder so it will not create a duplicate insert.
     *  This function will create one SOQL statement for each sObject Domain builder Type.  
     *  All fields that are registered per each sObject will be queried in one SQL.
     * 
     *  Example:    
     *      If three domain builders are registered (Account,Case, Contact)
     *      Then one soql statement will be generated for each.
     */
    public void determinePreExisting() {
        for (sObjectType sObjType : discoveryFieldsByObjectType.keySet()){

            //if there are no registered fields then iterate to the next object 
            if( (null == discoveryFieldsByObjectType.get(sObjType) ) ||
                (discoveryFieldsByObjectType.get(sObjType).keySet().isEmpty()) ) {
                continue;
            }

            fflib_QueryFactory queryFactory = new fflib_QueryFactory(sObjType);
            //Every SOQL will have the ID field returned by default
            queryFactory.selectField('Id');
            List<String> criteriasPerObject = new List<String>();
        
            //loop through the sKeys which are the field name keys
            for(String sKey : discoveryFieldsByObjectType.get(sObjType).keySet()) {
                //Loop through all the field names (actual api name for field) associated, usually only one per sKey
                for(String fieldName : discoveryFieldsByObjectType.get(sObjType).get(sKey)) {
                    
                    if (String.isBlank(fieldName) ) {continue; }
                    queryFactory.selectField(fieldName);
                   
                    //Convert the list of values and field to a '<Field> IN (val1,val2) clause'
                    String clause = convertConditionToString(fieldName, sObjType, discoveryValues.get(sKey));
                    //store each field in clause so that they can be reassembled for one
                    //big WHERE clause below:
                    criteriasPerObject.add(clause);
                }
            }
         
            //join all the various clauses created for each discoverable field to create one WHERE statement
            //ex:  //example  <Field1> IN (<val1>,<val2>) OR <Field2> IN (<val1>,<val2>) 
            String criteriaAccum = String.join(criteriasPerObject, ' OR ');
            queryFactory.setCondition(criteriaAccum);
            List<sObject> recsFound = Database.query(queryFactory.toSoql());

            if (recsFound.isEmpty()) { continue;}  

            for(String sKey : discoveryFieldsByObjectType.get(sObjType).keySet()) {
                String searchField = discoveryFieldsByObjectType.get(sObjType).get(sKey)[0];
                
                for(sObject found : recsFound) {
                    String fKey = sKey + '_' + found.get(searchField);
                    if (!discoveries.containsKey(fKey)) { continue; }
                    if (discoveries.get(fKey).getRecord().get(searchField) != found.get(searchField)) { continue; }
                    if (discoveries.get(fKey).getRecord().Id != null) { continue; }
                    discoveries.get(fKey).getRecord().Id = found.Id;
                }
            }
        }
    }

    /*
     *  Creates a "IN" statement for use in SOQL, as String
     *  @param          fieldName       String          The Field being queried
     *  @param          searchObject    SObjectType     The Type of the SObject being queried
     *  @param          values          List<Object>    The list of data to convert into a "WHERE IN" statement
     *  @return         List of String values converted from incomming values
     */
    private List<String> convertToString(List<Object> values) {
        List<String> strings = new List<String>();
        for(Object v : values) { strings.add('\'' + String.valueOf(v) + '\''); }
        return Strings;
    }

    /*
     *  Creates a "IN" statement for use in SOQL, as Double
     *  @param          fieldName       String          The Field being queried
     *  @param          searchObject    SObjectType     The Type of the SObject being queried
     *  @param          values          List<Object>    The list of data to convert into a "WHERE IN" statement
     *  @return         List of Double values converted from incomming values
     */
    private List<Double> convertToNumber(List<Object> values) {
        List<Double> decimals = new List<Double>();
        for(Object v : values) { decimals.add(Double.valueOf(v)); }
        
        return decimals;
    }

    /*
     *  Creates a "IN" statement for use in SOQL, as Integer
     *  @param          fieldName       String          The Field being queried
     *  @param          searchObject    SObjectType     The Type of the SObject being queried
     *  @param          values          List<Object>    The list of data to convert into a "WHERE IN" statement
     *  @return         List of Integer values converted from incomming values
     */
    private List<Integer> convertToInteger(List<Object> values){
       List<Integer> integers  = new List<Integer>();
        for(Object v : values) { integers.add(Integer.valueOf(v)); }
        
        return integers; 
    }

    /*
     *  Creates a "IN" statement for use in SOQL, as DateTime
     *  @param          fieldName       String          The Field being queried
     *  @param          searchObject    SObjectType     The Type of the SObject being queried
     *  @param          values          List<Object>    The list of data to convert into a "WHERE IN" statement
     *  @return         List of DateTime values converted from incomming values
     */
    private List<DateTime>  convertToDateTime(List<Object> values) {
        List<DateTime> datetimes = new List<DateTime>();
        for(Object v : values) { datetimes.add(DateTime.valueOf(v)); }
       
        return datetimes;
    }

    /*
     *  Creates a "IN" statement for use in SOQL, as Boolean
     *  @param          fieldName       String          The Field being queried
     *  @param          searchObject    SObjectType     The Type of the SObject being queried
     *  @param          values          List<Object>    The list of data to convert into a "WHERE IN" statement
     *  @return         List of Boolean values converted from incomming values
     */
    private List <Boolean> convertToBool(List<Object> values) {
        List <Boolean> bools = new List<Boolean>();
        for(Object v : values) { 
            Boolean b = Boolean.valueOf(v);
            if (!bools.contains(b)) { bools.add(Boolean.valueOf(v)); }
        }

        return bools;
    }

    /*
     *  Creates a "IN" statement for use in SOQL
     *  @param          fieldName       String          The Field being queried
     *  @param          searchObject    SObjectType     The Type of the SObject being queried
     *  @param          values          List<Object>    The list of data to convert into a "WHERE IN" statement
     *  @return         String representing the IN comparison
     */
    private String convertConditionToString(String fieldName, sObjectType searchObject, List<object> values)
    {
        String retString ='';
        if (!String.isBlank(fieldName) &&  !values.isEmpty() )
        {
           retString = fieldName + ' IN (' + 
                appendListCondition( fieldName, searchObject, values) + ') ';
        }   
    
       return(retString);
    }

    /*
     *  Creates a "IN" statement for use in SOQL
     *  @param          fieldName       String          The Field being queried
     *  @param          searchObject    SObjectType     The Type of the SObject being queried
     *  @param          values          List<Object>    The list of data to convert into a "WHERE IN" statement
     *  @return         String representing the IN comparison's list of values
     */
    private  String appendListCondition( String fieldName, SObjectType searchObject, List<Object> values) {
        SObjectField fieldType = getSObjectFieldFor(searchObject, fieldName);
        DescribeFieldResult detail = fieldType.getDescribe();
        DisplayType kind = detail.getType();
        
        switch on kind {
            when Boolean {
                return  String.Join(convertToBool(values), ',');
            }
            when  Double, Long, Currency, Percent {
                return String.Join(convertToNumber(values), ',');
            }
            when Integer {
                return String.join(convertToInteger(values), ',');
            }
            when Date, DateTime {
                return String.join(convertToDateTime(values), ',');
            }
            when else {
                return String.join(convertToString(values), ',');
            }
        }
    }

    
    /*
     *  Retrieves SObjectField for a given SObject from a specified Field
     *  @param          obj         SObjectType     The Type of the SObject to retrieve SObjectField from
     *  @param          fieldName   String          The Field of the SObject to retrieve SObjectField from
     *  @return         The SObjectField for the given string field name
     */
    private SObjectField getSObjectFieldFor(SObjectType obj, String fieldName) {
        String testString = obj.getDescribe().getName() + '.' + fieldName;

        List<String> splitString = testString.split('\\.');

        return Schema.getGlobalDescribe().get(splitString[0]).getDescribe().fields.getMap().get(splitString[1]);
    }

    /**
     *  FOR INTERNAL USE ONLY
     *  Parses provided list of dbf_IDomainBuilder to determine order of operations and define a fflib_SObjectUnitOfWork
     *  @param          registeredBuilders  List<dbf_IDomainBuilder>    The list of builders to prepare a Unit of Work for
     *  @param          setupUow            fflib_SObjectUnitOfWork     The "Setup" Unit of Work
     *  @param          dataUow             fflib_SObjectUnitOfWork     The "Data" Unit of Work
     */
    public void prepareUoW(List<dbf_IDomainBuilder> registeredBuilders, fflib_SObjectUnitOfWork setupUow, fflib_SObjectUnitOfWork dataUow) {
        for(dbf_IDomainBuilder obj : registeredBuilders) {
            fflib_SObjectUnitOfWork uow = (obj.isSetupObject()) ? setupUow : dataUow;

            if(obj.getId() == null) {
                uow.registerNew(obj.getRecord());
            }
           
            if (parentByRelationship.containsKey(obj)) {
                for(SObjectField rel: parentByRelationship.get(obj).keySet()) {
                    dbf_IDomainBuilder parent = parentByRelationship.get(obj).get(rel);
                    if (parent.getId() != null) {
                        obj.getRecord().put(rel, parent.getId());
                        continue;
                    }
                    uow.registerRelationship(obj.getRecord(), rel, parent.getRecord());
                }
            }

            if (externalIdReferences.containsKey(obj)) {
                for(dbf_DomainBuilderExtRef ref : externalIdReferences.get(obj)) {
                    uow.registerRelationship(obj.getRecord(), ref.getRelationshipField(), ref.getExternalIdField(), ref.getExternalId());
                }
            }
        }
    }

    /**
     *  FOR INTERNAL USE ONLY
     *  Applies the parent relationship to between two dbf_IDomainBuilder instances
     *  @param          source          dbf_IDomainBuilder  The builder which holds the relationship
     *  @param          relationship    SObjectField        The Field on the builder which holds the relationship
     *  @param          parent          dbf_IDomainBuilder  The builder which acts as the targetted Parent
     */
    public void setParent(dbf_IDomainBuilder source, SObjectField relationship, dbf_IDomainBuilder parent) {
        if (!parentByRelationship.containsKey(source)) {
            parentByRelationship.put(source, new Map<SObjectField, dbf_IDomainBuilder>());
        }

        // Note: The parent registered last always wins!
        dbf_IDomainBuilder oldParent = parentByRelationship.get(source).get(relationship);

        // Note: Sometime we manually unregister parent that are set by default constructor
        if(parent != null) {
            parentByRelationship.get(source).put(relationship, parent);
        }

        if(oldParent != null && oldParent != parent) {
            oldParent.unregisterIncludingParents();
        }

        if (!parentByRelationship.containsKey(source)) {
            parentByRelationship.put(source, new Map<SObjectField, dbf_IDomainBuilder>());
        }

        //Map<dbf_IDomainBuilder, Map<SObjectField, Map<SObjectField, List<dbf_IDomainBuilder>>>>
        if (!relationshipsToSync.containsKey(source)) {
            relationshipsToSync.put(source, new Map<SObjectField, Map<SObjectField, List<dbf_IDomainBuilder>>>());
        }
        if(relationshipsToSync.get(source).containsKey(relationship)) {
            synchronize(source, relationship);
        }
    }

    /**
     *  FOR INTERNAL USE ONLY
     *  Applies the external id relationship between two dbf_IDomainBuilder instances
     *  @param          source                  dbf_IDomainBuilder  The builder which holds the relationship
     *  @param          relatedToField          SObjectField        The Field on source which holds the relationship
     *  @param          targetExternalIdField   SObjectField        The target SObject's External ID field (SObject is deduced from the field provided)
     *  @param          externalId              Object              The value that should reside in targetExternalIdField
     *  @return         The Type of the SObject deduced from the targetExternalIdField
     */
    public virtual SObjectType setReference(dbf_IDomainBuilder source, SObjectField relatedToField, SObjectField targetExternalIdField, Object externalId) {
        if (relatedToField == null) { return null; }
        if (targetExternalIdField == null) { return null; }
        if (externalId == null) { return null; }

        if (!externalIdReferences.containsKey(source)) {
            externalIdReferences.put(source, new Set<dbf_DomainBuilderExtRef>());
        }

        dbf_DomainBuilderExtRef theRef = new dbf_DomainBuilderExtRef()
            .withRelationshipField(relatedToField)
            .targettingExternalIdField(targetExternalIdField)
            .forValue(externalId);
        externalIdReferences.get(source).add(theRef);

        return theRef.getExternalType();
    }

    /**
     *  FOR INTERNAL USE ONLY
     *  Synchronizes changes on one field with another field
     *  @param          source          dbf_IDomainBuilder  The builder to synchronize changes from
     *  @param          sourceField     SObjectField        The field to synchronize changes from 
     *  @param          targetObject    dbf_IDomainBuilder  The builder to synchronize changes to
     *  @param          targetField     SObjectField        The field to synchronize changes to
     */
    public void syncOnChange(dbf_IDomainBuilder source, SObjectField sourceField, dbf_IDomainBuilder targetObject, SObjectField targetField) {
        if (!relationshipsToSync.containsKey(source)) {
            relationshipsToSync.put(source, new Map<SObjectField, Map<SObjectField, List<dbf_IDomainBuilder>>>());
        }
        if( !relationshipsToSync.get(source).containsKey(sourceField)) {
            relationshipsToSync.get(source).put(sourceField, new Map<SObjectField, List<dbf_IDomainBuilder>>());
        }
        if( !relationshipsToSync.get(source).get(sourceField).containsKey(targetField)) {
            relationshipsToSync.get(source).get(sourceField).put(targetField, new List<dbf_IDomainBuilder>());
        }

        relationshipsToSync.get(source).get(sourceField).get(targetField).add(targetObject);

        synchronize(source, sourceField);
    }
    
    /*
     *  Synchronizes changes across builder relationships that have been defined to be synchronized
     *  @param          source          dbf_IDomainBuilder      The builder to synchronize changes for
     *  @param          sourceField     SObjectField            The field to synchronize changes for
     */
    private void synchronize(dbf_IDomainBuilder source, SObjectField sourceField) {
        if (!relationshipsToSync.containsKey(source)) {
            relationshipsToSync.put(source, new Map<SObjectField, Map<SObjectField, List<dbf_IDomainBuilder>>>());
        }
        for(SObjectField targetField: relationshipsToSync.get(source).get(sourceField).keySet()) {
            for(dbf_IDomainBuilder obj : relationshipsToSync.get(source).get(sourceField).get(targetField)) {

                dbf_IDomainBuilder parent = parentByRelationship.get(source).get(sourceField);
                obj.setParent(targetField, parent);
            }
        }
    }

    /**
     *  FOR INTERNAL USE ONLY
     *  Removes parent relationships that might've been assigned to a given dbf_IDomainBuilder
     *  @param          source      dbf_IDomainBuilder      The builder to de-register all parent related Builder(s) for
     */
    public void unregisterParents(dbf_IDomainBuilder source) {
        if (!parentByRelationship.containsKey(source)) {
            parentByRelationship.put(source, new Map<SObjectField, dbf_IDomainBuilder>());
        }

        for(dbf_IDomainBuilder parent : parentByRelationship.get(source).values()) {
            parent.unregisterIncludingParents();
        }
    }

    /**
     *  FOR INTERNAL USE ONLY
     *  Registers parent relationships for a given dbf_IDomainBuilder
     *  @param          source      dbf_IDomainBuilder      The builder to register all parent related Builder(s) for
     */
    public void registerParents(dbf_IDomainBuilder source) {
        if (!parentByRelationship.containsKey(source)) {
            parentByRelationship.put(source, new Map<SObjectField, dbf_IDomainBuilder>());
        }

        for(dbf_IDomainBuilder parent: parentByRelationship.get(source).values()) {
            parent.registerIncludingParents();
        }
    }

    /**
     *  FOR INTERNAL USE ONLY
     *  Registers an applied value on a given field in a dbf_IDomainBuilder's sObject to be discovered later by other builders
     *  @param          targetType      SObjectType         The Type of the SObject to register for data discovery
     *  @param          target          dbf_IDomainBuilder  The Domain Builder to link when data is later discovered
     *  @param          fieldName       String              The Field of the SObject to register for data discovery
     *  @param          value           Object              The value used for data discovery
     */
    public void registerForDiscovery(SObjectType targetType, dbf_IDomainBuilder target, String fieldName, Object value) {
        if (value == null) { return; }
        if (discoverableFields.containsKey(targetType)) {
            if (!discoveryFieldsByObjectType.containsKey(targettype) ) { 
                discoveryFieldsByObjectType.put(targetType, new Map<String, List<String>> ());
            }
       
            if (discoverableFields.get(targetType).contains(fieldName)) {
               
                String dKey = keyFor(targetType, fieldName, value);
                discoveries.put(dKey, target);
                String sKey = keyFor(targetType, fieldName);

                discoveryFields.put(sKey, fieldName);
              
                if (!discoveryFieldsByObjectType.get(targetType).containsKey(sKey)) {
                    discoveryFieldsByObjectType.get(targetType).put(sKey,new List<String>()); 
                } 

                if (!discoveryFieldsByObjectType.get(targetType).get(sKey).contains(FieldName)) {
                    discoveryFieldsByObjectType.get(targetType).get(sKey).add(fieldName);
                }

                if (!discoveryValues.containsKey(sKey)) { discoveryValues.put(sKey, new List<Object>()); }
                if (!discoveryValues.get(sKey).contains(value)) { discoveryValues.get(sKey).add(value); }
            }
        }
    }


    /**
     *  Finds an existing, registered Domain Builder parent, by field and value
     *  @param          targetType      SObjectType     The Type of the SObject to check for data discovery
     *  @param          targetField     SObjectField    The Field on the SObject to check for data discovery
     *  @param          targetValue     Object          The value to look for
     *  @return         The discovered Domain Builder, or null
     */
    public dbf_IDomainBuilder discoverRelationshipFor(SObjectType targetType, SObjectField targetField, Object targetValue) {
        String key = keyFor(targetType, targetField, targetValue);
        if (discoveries.containsKey(key)) {
            return discoveries.get(key);
        }
        return null;
    }


    /**
     *  Maps a field on the current Domain Builder as one that can be discovered using discoverRelationshipFor()
     *  Causes set() operations to watch for the given field, and getRecord() the value/builder as a discoverable relationship 
     *    when that field has a value pushed to it.
     *  @param          targetType      SObjectType     The Type of the SObject to watch for data discovery
     *  @param          field           String          The Field on the SObject to watch for data discovery
     *  @return         The current Domain Builder
     */
    public void setDiscoverableField(SObjectType targetType, String field) {
        if (!discoverableFields.containsKey(targetType)) { discoverableFields.put(targetType, new List<String>()); }
        if (!discoverableFields.get(targetType).contains(field)) { discoverableFields.get(targetType).add(field); }
    }


    /**
     *  Maps a field on the current Domain Builder as one that can be discovered using discoverRelationshipFor()
     *  Causes set() operations to watch for the given field, and getRecord() the value/builder as a discoverable relationship 
     *    when that field has a value pushed to it.
     *  @param          targetType      SObjectType     The Type of the SObject to watch for data discovery
     *  @param          field           SObjectField    The Field on the SObject to watch for data discovery
     */
    public void setDiscoverableField(SObjectType targetType, SObjectField field) {
        setDiscoverableField(targetType, field.getDescribe().getName());
    }


    /**
     *  Generates a discovery key for a type, field and value
     *  @param          onType          SObjectType     The object type a key is being generated for 
     *  @param          withKeyField    SObjectField    The field a key is being generated for
     *  @param          withKeyValue    Object          The value a key is being generated for
     *  @return         The generated key
     */
    public String keyFor(SObjectType onType, SObjectField withKeyField, Object withKeyValue) {
        return String.valueOf(onType) + '_' + withKeyField.getDescribe().getName() + '_' + String.valueOf(withKeyValue);
    }


    /**
     *  Generates a discovery key for a type, field and value
     *  @param          onType          SObjectType     The object type a key is being generated for 
     *  @param          withKeyField    String          The field a key is being generated for
     *  @param          withKeyValue    Object          The value a key is being generated for
     *  @return         The generated key
     */
    public String keyFor(SObjectType onType, String withKeyField, Object withKeyValue) {
        return String.valueOf(onType) + '_' + withKeyField + '_' + String.valueOf(withKeyValue);
    }


    /**
     *  Generates a discovery key for a type, field
     *  @param          onType          SObjectType     The object type a key is being generated for 
     *  @param          withKeyField    SObjectField    The field a key is being generated for
     *  @return         The generated key
     */
    public String keyFor(SObjectType onType, SObjectField withKeyField) {
        return String.valueOf(onType) + '_' + withKeyField.getDescribe().getName();
    }


    /**
     *  Generates a discovery key for a type, field
     *  @param          onType          SObjectType     The object type a key is being generated for 
     *  @param          withKeyField    String          The field a key is being generated for
     *  @return         The generated key
     */
    public String keyFor(SObjectType onType, String withKeyField) {
        return String.valueOf(onType) + '_' + withKeyField;
    }
}