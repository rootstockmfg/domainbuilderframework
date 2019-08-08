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
 *  Domain Builder Mock Database. Contains SObject data in a retrievable, filterable fashion. Data 
 *  is to be generated through Domain Builder pattern, and returned through this model via .mock() 
 *  as an alternative to .persist() when dml operations are not desired, or are unnecessary. Optimal 
 *  use case is within the confines of unit tests that do not require DML to execute.
 */
public with sharing class dbf_DomainBuilderMockDB implements dbf_IDomainBuilderMockDB {
    /*
     *  Represents the generate "database" of SObjects
     */
    private Map<SObjectType, List<sObject>> db = new Map<SObjectType, List<sObject>>();

    /*
     *  Stores the list of builders supplied to create the Mock DB from
     */
    private List<dbf_IDomainBuilder> registeredBuilders = new List<dbf_IDomainBuilder>();

    /**
     *  Fluently adds a list of builders to the mock DB as a source of data to be mocked
     *  @param      builderList     List<dbf_IDomainBuilder>    The list of builders used to generate a dbf_IDomainBuilderMockDB
     *  @return     The current dbf_IDomainBuilderMockDB instance
     */
    public dbf_IDomainBuilderMockDB usingBuilders(List<dbf_IDomainBuilder> builderList) {
        registeredBuilders = builderList;
        return this;
    }

    /**
     *  Fluently triggers the mocked data to be filled with generated Id values
     *  @return     The current dbf_IDomainBuilderMockDB instance
     */
    public dbf_IDomainBuilderMockDB generateIds() {
        for(dbf_IDomainBuilder builder : registeredBuilders) {
            generateId(builder.getRecord());
        }
        return this;
    }

    /**
     *  Fluently assigns relationship values that would've been handled by the Unit of Work, had the data not been mocked
     *  @param      discGraph   dbf_DomainBuilderDiscGraph      The Discovery Graph to use for generating mock relationships
     *  @return     The current dbf_IDomainBuilderMockDB instance
     */
    public dbf_IDomainBuilderMockDB generateRelationships(dbf_DomainBuilderDiscGraph discGraph) {
        for(dbf_IDomainBuilder obj: registeredBuilders) {
            Map<SObjectField, dbf_IDomainBuilder> parentByRelationship = discGraph.getParentRelationMap(obj);

            if (parentByRelationship != null) {
                for(SObjectField rel : parentByRelationship.keySet()) {
                    dbf_IDomainBuilder parent = parentByRelationship.get(rel);
                    obj.getRecord().put(rel, parent.getId());
                }
            }

            Set<dbf_DomainBuilderExtRef> externalIdReferences = discGraph.getExternalReferences(obj);
            if (externalIdReferences != null) {
                for(dbf_DomainBuilderExtRef ref : externalIdReferences) {
                    for (dbf_IDomainBuilder potential: registeredBuilders) {
                        if (potential.getType() != ref.getExternalType()) { continue; }
                        if (potential.getRecord().get(ref.getExternalIdField()) != ref.getExternalId()) { continue; }
                        obj.getRecord().put(ref.getRelationshipField(), potential.getId());
                    }
                }
            }
        }
        return this;
    }

    /**
     *  Fluently pulls the data from within the dbf_DomainBuilder instances into the mock database
     *  @return     The current dbf_IDomainBuilderMockDB instance
     */
    public dbf_IDomainBuilderMockDB store() {
        for(dbf_IDomainBuilder builder : registeredBuilders) {
            store(builder.getRecord());
        }
        return this;
    }

    /**
     *  Fluently pulls the data from within the provided SObject into the mock database
     *  @param      storableObject      sObject     The SObject to store in the Mock DB
     *  @return     The current dbf_IDomainBuilderMockDB instance
     */
    public dbf_IDomainBuilderMockDB store(sObject storableObject) {
        SObjectType type = storableObject.getSObjectType();
        if (!db.containsKey(type)) { db.put(type, new List<sObject>()); }
        if (!db.get(type).contains(storableObject)) { db.get(type).add(storableObject); }
        return (dbf_IDomainBuilderMockDB) this;
    }

    /**
     *  Fluently pulls the data from within the provided list of SObjects into the mock database
     *  @param      storableObjects     List<sObject>   The list of SObjects to store in the Mock DB
     *  @return     The current dbf_IDomainBuilderMockDB instance
     */
    public dbf_IDomainBuilderMockDB store(List<sObject> storableObjects) {
        for (sObject obj : storableObjects) {
            store(obj);
        }
        return (dbf_IDomainBuilderMockDB) this;
    }

    /**
     *  Fluently generates an Id for the provided SObject
     *  @param      obj     sObject     The SObject to generate mock ID values for
     *  @return     The current dbf_IDomainBuilderMockDB instance
     */
    public dbf_IDomainBuilderMockDB generateId(sObject obj) {
        if(obj.Id == null) {
            obj.Id = fflib_IDGenerator.generate(obj.getSObjectType());
        }
        return this;
    }

    /**
     *  Fluently generates an Id for the provided list of SObjects
     *  @param      registeredObjects       List<sObject>       The list of SObjects to generate mock ID values for
     *  @return     The current dbf_IDomainBuilderMockDB instance
     */
    public dbf_IDomainBuilderMockDB generateIds(List<sObject> registeredObjects) {
        for(sObject obj: registeredObjects) {
            generateId(obj);
        }
        return this;
    }

    /**
     *  Retrieves all stored data for the given SObjectType
     *  @param      retrievalType       SObjectType     The SObject Type to retrieve data for
     *  @return     The data for the requested SObject Type
     */
    public List<sObject> retrieve(SObjectType retrievalType) {
        return db.containsKey(retrievalType) ? db.get(retrievalType) : null;
    }

    /**
     *  Retrieves all stored data for the given SObjectType, filtered using the provided map
     *  @param      retrievalType       SObjectType                 The SObject Type to retrieve data for
     *  @param      filters             Map<SObjectField, Object>   An SObjectField to Value map used to filter the requested SObject's data
     *  @return     The data for the requested SObject Type using the provided filters map
     */
    public List<sObject> retrieveByFilter(SObjectType retrievalType, Map<SObjectField, Object> filters) {
        List<sObject> toFilter = retrieve(retrievalType);
        if (filters == null) { return toFilter; }
        if (filters.isEmpty()) { return toFilter; }
        if (toFilter == null) { return null; }
        List<sObject> filtered = new List<sObject>();
        for(sObject obj : toFilter) {
            Boolean matches = true;
            for (SObjectField field : filters.keySet()) {
                String a = String.valueOf(obj.get(field));
                String b = String.valueOf(filters.get(field));
                if (a != b) { matches = false; }
            }
            if (matches) { filtered.add(obj); }
        }
        return filtered.isEmpty() ? null : filtered;
    }
}
