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
 *  Domain Builder Directed Graph. Directs the flow of the Unit of Work created by Domain Builder 
 *  by tracking relationships and plotting order of operations automatically.
 */
public with sharing class dbf_DomainBuilderUoWGraph {
    Map<SObjectType, Integer> childCount = new Map<SObjectType, Integer>();
    Set<SObjectType> pureChilds = new Set<SObjectType>();
    Map<SObjectType, Set<SObjectType>> parents = new Map<SObjectType, Set<SObjectType>>();

    /**
     *  Fluently adds a node to the graph
     *  @param      type        SObjectType     The Type of sObject being listed
     *  @return     The current dbf_DomainBuilderUoWGraph instance
     */
    public dbf_DomainBuilderUoWGraph node(SObjectType type) {
        if(!parents.containsKey(type)) {
            parents.put(type, new Set<SObjectType>());
        }

        return this;
    }

    /**
     *  Fluently adds an edge, or relationship, to the graph
     *  @param      child       SObjectType     The Type of sObject being listed as Child
     *  @param      parent      SObjectType     The Type of sObject being listed as Parent
     *  @return     The current dbf_DomainBuilderUoWGraph instance
     */
    public dbf_DomainBuilderUoWGraph edge(SObjectType child, SObjectType parent) {
        parents.get(child).add(parent);
        return this;
    }

    /**
     *  Sorts the provided nodes by their edge relationships, producing a list that represents 
     *  an order of operations for Unit of Work to utilize
     *  @return         The sorted SObjectType list
     */
    public List<SObjectType> sortTopologically() {
        List<SObjectType> result = new List<SObjectType>();

        countDependencies();

        if(pureChilds.isEmpty()) {
            throw new dbf_CyclicGraphException('There are no records which have 0 parent dependencies.');
        }

        while(!pureChilds.isEmpty()) {
            SObjectType cur = (SObjectType) pureChilds.iterator().next();
            pureChilds.remove(cur);

            result.add(cur);

            for(SObjectType type : parents.get(cur)) {
                Integer newCnt = childCount.get(type) - 1;
                childCount.put(type, newCnt);

                if(newCnt == 0) {
                    pureChilds.add(type);
                }
            }
        }

        if(result.size() != parents.size()) {
            throw new dbf_CyclicGraphException('Expected parent list not of matching size.');
        }

        return result;
    }

    /*
     *  Counts the number of dependencies for all sObject types listed as Parent
     */
    private void countDependencies() {
        for(SObjectType type : parents.keySet()) {
            if(!childCount.containsKey(type)) {
                pureChilds.add(type);
            }

            for(SObjectType parent : parents.get(type)) {
                pureChilds.remove(parent);

                if(!childCount.containsKey(parent)) {
                    childCount.put(parent, 1);
                }
                else {
                    childCount.put(parent, childCount.get(parent) + 1);
                }
            }
        }
    }

    
    /**
     *  custom Exception for cyclic references in Graph
     */
    public class dbf_CyclicGraphException extends Exception {}
}