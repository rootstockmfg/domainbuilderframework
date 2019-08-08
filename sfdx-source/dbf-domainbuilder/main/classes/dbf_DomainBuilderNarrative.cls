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
 *  Domain Builder Narrative. Defines a single 'persona', or 'state', of an SObject record. Designed 
 *  to be usable in conversation, in tickets and in code as a simple reference to an entire data 
 *  concept as it applies to a single SObject record.
 */
public with sharing abstract class dbf_DomainBuilderNarrative {

    /**
     *  Retrieves the assigned Type of the underlying dbf_DomainBuilder
     *  @return         The Type of the underlying dbf_DomainBuilder
     */ 
    public abstract Type builderType();

    /**
     *  Retrieves the SObjectType being populated with data
     *  @return         The SObjectType of the SObject contained within the underlying dbf_DomainBuilder
     */ 
    public abstract SObjectType sObjectType();

    /**
     *  Executes .build() across all assigned narratives, and registers them for commit through a uow
     *  @return         The underlying instance of dbf_DomainBuilder
     */ 
    public abstract dbf_IDomainBuilder build();
}
