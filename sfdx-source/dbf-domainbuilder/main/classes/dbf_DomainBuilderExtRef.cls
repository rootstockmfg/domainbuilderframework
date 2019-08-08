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
 *  Domain Builder External Reference. Used to store references to other sObjects via External ID field.
 */
public with sharing class dbf_DomainBuilderExtRef {
    /*
     *  The Field which holds the External ID relationship
     */
    private SObjectField relationshipField { get; set; }

    /*
     *  The External ID field of the target of the relationship
     */
    private SObjectField externalIdField { get; set; }

    /*
     *  The value that should reside in externalIdField
     */
    private Object externalId { get; set; }

    /*
     *  The Type of the SObject being targetted with the relationship
     */
    private SObjectType externalType { get; set; }
    
    /**
     *  Retrieves the SObjectField that holds the relationship
     *  @return     The SObjectField holding the relationship
     */
    public SObjectField getRelationshipField() { return relationshipField; }

    /**
     *  Retrieves the SObjectField on the target SObject that holds the external id value
     *  @return     The SObjectField targetted by the relationship
     */
    public SObjectField getExternalIdField() { return externalIdField; }

    /**
     *  Retrieves the value that should be present in the ExternalIdField on the target SObject
     *  @return     The value being sought in the External ID field of the target
     */
    public Object getExternalId() { return externalId; }

    /**
     *  Retrieves the SObjectType of the SObject that contains the ExternalIdField
     *  @return     The Type of the SObject that holds the External ID field being targetted
     */
    public SObjectType getExternalType() {
        if (externalType != null) { return externalType; }
        String relationshipName = relationshipField.getDescribe().getRelationshipName();
        if (String.isBlank(relationshipName)) {
            throw new fflib_SObjectUnitOfWork.UnitOfWorkException('[DBF] Invalid argument: relationshipField. Field supplied is not a relationship field.');
        }
        List<SObjectType> relatedObjects = relationshipField.getDescribe().getReferenceTo();
        externalType = relatedObjects[0];
        return externalType;
    }

    /**
     *  Fluently assigns the SObjectField that holds the proposed relationship
     *  @return     The current dbf_DomainBuilderExtRef instance
     */
    public dbf_DomainBuilderExtRef withRelationshipField(SObjectField field) { relationshipField = field; externalType = null; return this; }

    /**
     *  Fluently assigns the SObjectField on the SObject that is being targetted for the relationship
     *  @return     The current dbf_DomainBuilderExtRef instance
     */
    public dbf_DomainBuilderExtRef targettingExternalIdField(SObjectField field) { externalIdField = field; return this; }

    /**
     *  Fluently assigns the value that should be looked for in the ExternalIdField of the targetted SObject
     *  @return     The current dbf_DomainBuilderExtRef instance
     */
    public dbf_DomainBuilderExtRef forValue(Object target) { externalId = target; return this; }
}