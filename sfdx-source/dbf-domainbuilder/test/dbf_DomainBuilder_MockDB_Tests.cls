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
@IsTest
private class dbf_DomainBuilder_MockDB_Tests {
    class OpportunityBuilder_t extends dbf_DomainBuilder {
        public OpportunityBuilder_t() {
            super(Opportunity.sObjectType);
            setDiscoverableField(Opportunity.Name);
        }
    }

    @IsTest
    private static void mockAnOpportunity() {
        String testName = 'Acme Welding';
        // instantiate the builder
        dbf_IDomainBuilder builder = (dbf_IDomainBuilder) new OpportunityBuilder_t().set(Opportunity.Name, testName);
        // call mock
        dbf_IDomainBuilderMockDB db = builder.mock();
        // extract an object by name
        List<Opportunity> records = (List<Opportunity>) db.retrieveByFilter(Opportunity.sObjectType, new Map<SObjectField, Object> {
            Opportunity.Name => testName
        });

        System.assert(records != null);
        System.assert(!records.isEmpty());
        System.assert(records[0].Id != null);
    }

}
