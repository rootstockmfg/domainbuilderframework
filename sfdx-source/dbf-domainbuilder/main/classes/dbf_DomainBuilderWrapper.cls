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
 *   Domain Builder Wrapper. Used to wrap Domain Builders implemented in a Managed Package and provide 
 *   support for reclaimation of data before persist/mock.
 *   EXAMPLE SCENARIO:
 *       ~ Your org has a managed package installed named AcmeEmailer, with a namespace of 'ae'
 *       ~ There exists an 'ae__EmailAccountBuilder' implementation of the package's own copy of domain builder framework
 *       ~ Your org needs a customized version of ae__EmailAccountBuilder
 *       ~ Your org also implements its own domain builder framework
 *       ~ You would implement a wrapper for ae__EmailAccountBuilder, possibly named EmailAccountBuilderWrapper
 *       ~ Your code could then implement narratives against the EmailAccountBuilderWrapper to push data through ae__EmailAccountBuilder
 *       ~ When persist() or mock() is eventually executed on the stack of builders, the ae__EmailAccountBuilder is executed and the underlying SObject rescued
 *         and pulled into your local builder, to maintain a single transaction and a single unit of work
 */
public with sharing abstract class dbf_IDomainBuilderWrapper extends dbf_DomainBuilder implements dbf_IDomainBuilderReclaimableWrapper {

    // REGION: CONSTRUCTORS

    public dbf_IDomainBuilderWrapper(SObjectType type, Boolean isSetupObject) {
        super(type, isSetupObject);
        super.forExternal(this);
    }

    public dbf_IDomainBuilderWrapper(SObjectType type) {
        super(type);
        super.forExternal(this);
    }


    // REGION: ABSTRACT METHODS

    /**
     *  Retrieves the rstk_sydivBuilder underlying this builder
     *  @return         Current builder instance as an Object, to be cast externally
     */ 
    public abstract Object underlyingBuilder();

    /**
     *  Retrieves the rst__sydiv__c object underlying the underlyingBuilder()
     *  @return         Current sObject and all data so far defined
     */ 
    public abstract SObject underlyingRecord();


    // REGION: DEFAULT IMPLEMENTATIONS

    /**
     *  The instance of dbf_IDomainBuilder that this Wrapper encapsulates
     */ 
    public virtual dbf_IDomainBuilder implementingBuilder() { return this; }
}