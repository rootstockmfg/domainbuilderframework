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
public interface dbf_IDomainBuilder {
    /**
     *  Retrieves the underlying sObject whose data is being constructed
     *  @return         An sObject representative of the original SObjectType, filled with supplied data
     */
    sObject getRecord();

    /**
     *  Retrieves the underlying sObject's Id value
     *  @return         An Id from the underlying sObject, or null if none has been supplied yet
     */
    Id getId();

    /**
     *  Retrieves the underlying sObject's SObjectType
     *  @return         The SObjectType of the underlying sObject
     */
    SObjectType getType();

    /**
     *  Descripes whether or not the SObject was created as a Setup Object or not
     *  @return         Boolean
     */
    Boolean isSetupObject();
    
    /**
     *  Persists all registered Domain Builders' sObjects to the Org, in order by UoW Graph
     *  @return         The sObject of the current Domain Builder
     */
    sObject persist();

    /**
     *  Assigns the provided Field with the provided Value
     *  @param          fieldName   String      The field to be assigned a value
     *  @param          value       Object      The value to be assigned
     *  @return         The current Domain Builder
     */
    dbf_IDomainBuilder set(String fieldName, Object value);

    /**
     *  Assigns the provided Field with the provided Value
     *  @param          fieldName   SObjectField    The field to be assigned a value
     *  @param          value       Object          The value to be assigned
     *  @return         The current Domain Builder
     */
    dbf_IDomainBuilder set(SObjectField field, Object value);

    /**
     *  Assigns the Developer Name to the current sObject
     *  @param          developerName   String  The collection in which to source RecordTypeId value
     *  @return         The current Domain Builder
     */
    dbf_IDomainBuilder recordType(String developerName);
    
    /**
     *  Suspends, or shelves, the value for a Restricted, or Formula, field.
     *  Prevents DML errors, as restricted fields are NOT pushed to DML operations.
     *  Allows for retrieval of the suspended value in Mock usage.
     *  @param          fieldName   SObjectField    The field to be assigned a value
     *  @param          value       Object          The value to be assigned
     *  @return         The current Domain Builder
     */
    dbf_IDomainBuilder assignRestrictedFieldValue(SObjectField field, Object value);

    /**
     *  Mocks all registered Domain Builders' sObjects to an instance of dbf_IDomainBuilderMockDB
     *  @return         The dbf_IDomainBuilderMockDB containing all sObjects generated
     */
    dbf_IDomainBuilderMockDB mock();

    /**
     *  Finds an existing, registered Domain Builder parent, by field and value
     *  @param          target      dbf_IDomainBuilder  The Domain Builder to listed for discoveries
     *  @param          fieldName   String          The field to be listed
     *  @param          value       Object          The value to be listed
     *  @return         The discovered Domain Builder
     */
    dbf_IDomainBuilder registerDiscoverable(dbf_IDomainBuilder target, String fieldName, Object value);

    /**
     *  Finds an existing, registered Domain Builder parent, by field and value
     *  @param          targetType  SObjectType     The Type of the SObject being searched for
     *  @param          targetField SObjectField    The field to be searched
     *  @param          targetValue Object          The value to be searched for
     *  @return         The discovered Domain Builder, or null
     */
    dbf_IDomainBuilder discoverRelatedBuilder(SObjectType targetType, SObjectField targetField, Object targetValue);

    /**
     *  Maps a field on the current Domain Builder as one that can be discovered using discoverRelationshipFor()
     *  Causes set() operations to watch for the given field, and record the value/builder as a discoverable relationship 
     *    when that field has a value pushed to it.
     *  @param          targetType  SObjectType     The Type of the SObject being watched
     *  @param          field       String          The field to be watched
     *  @return         The current Domain Builder
     */
    void setDiscoverableField(SObjectType targetType, String field);

    /**
     *  Maps a field on the current Domain Builder as one that can be discovered using discoverRelationshipFor()
     *  Causes set() operations to watch for the given field, and record the value/builder as a discoverable relationship 
     *    when that field has a value pushed to it.
     *  @param          field       String          The field to be watched
     *  @return         The current Domain Builder
     */
    void setDiscoverableField(String field);

    /**
     *  Maps a field on the current Domain Builder as one that can be discovered using discoverRelationshipFor()
     *  Causes set() operations to watch for the given field, and record the value/builder as a discoverable relationship 
     *    when that field has a value pushed to it.
     *  @param          targetType      SObjectType     The Type of the SObject being watched
     *  @param          targetField     SObjectField    The field to be watched
     *  @return         The current Domain Builder
     */
    void setDiscoverableField(SObjectType targetType, SObjectField field);

    /**
     *  Maps a field on the current Domain Builder as one that can be discovered using discoverRelationshipFor()
     *  Causes set() operations to watch for the given field, and record the value/builder as a discoverable relationship 
     *    when that field has a value pushed to it.
     *  @param          targetField     SObjectField    The field to be watched
     *  @return         The current Domain Builder
     */
    void setDiscoverableField(SObjectField field);

    /**
     *  Assigns another dbf_IDomainBuilder as the current builder's parent
     *  @param          relationship    SObjectField        The field which refers to the parent
     *  @param          parent          dbf_IDomainBuilder  The builder to which a relationship should exist
     *  @return         The current Domain Builder
     */
    dbf_IDomainBuilder setParent(SObjectField relationship, dbf_IDomainBuilder parent);

    /**
     *  Assigns another dbf_IDomainBuilder as the current builder's child
     *  @param          relationship    SObjectField        The field which refers to the parent
     *  @param          child           dbf_IDomainBuilder  The builder to which a relationship should exist
     *  @return         The current Domain Builder
     */
    dbf_IDomainBuilder setChild(SObjectField relationship, dbf_IDomainBuilder child);

    /**
     *  Assigns an External ID reference to a another SObject for the given field
     *  @param          relatedToField          SObjectField    The field that should hold the relationship
     *  @param          targetExternalIdField   SObjectField    The target's External ID field
     *  @param          externalId              Object          The value that should exist in the targetted SObject's External ID field
     *  @return         The current Domain Builder
     */
    dbf_IDomainBuilder setReference(SObjectField relatedToField, SObjectField targetExternalIdField, Object externalId);

    /**
     *  Registers the current comain builder and its upstream.
     *  @return         The current Domain Builder
     */
    dbf_IDomainBuilder registerIncludingParents();

    /**
     *  Removes the current Domain Builder from the list of registered builders, including upstream relationships
     */
    void unregisterIncludingParents();

    /**
     *  Synchronizes changes on one field with another field
     */
    void syncOnChange(SObjectField sourceField, dbf_IDomainBuilder targetObject, SObjectField targetField);
}
