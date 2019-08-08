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
 *  Domain Builder Story. Defines a combination of several Domain Builder Narrative which combine 
 *  to tell an entire tale. Designed to be usable in conversation, in tickets and in code as a 
 *  simple reference to an entire data concept as it applies to a series of SObject records.
 */
public inherited sharing virtual class dbf_DomainBuilderStory {


    // REGION START: SUGGESTED OVERRIDES |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||

    /**
     *  A list of Narrators which refer to Narratives and their relationship map instructing how the DomainBuilders will provide data
     *  @return     The list of narrators
     */ 
    public virtual List<Narrator> narrators() {
        if (m_narrators == null) { m_narrators = new List<Narrator>(); }
        return m_narrators;
    }

    /**
     *  Defines the Domain Stories that relate to the current story, which will be built first
     *  @return     The list of dbf_DomainBuilderStory
     */ 
    public virtual List<dbf_DomainBuilderStory> relatedStories() { 
        if (m_stories == null) { m_stories = new List<dbf_DomainBuilderStory>(); }
        return m_stories; 
    }

    // REGION END: SUGGESTED OVERRIDES |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||



    // REGION START: PROPERTIES ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||

    /*
     *  list of narrators added. not likely used if narrators() is overridden
     */
    private List<Narrator> m_narrators = new List<Narrator>();

    /*
     *  list of stories added. not likely used if relatedStories() is overridden
     */
    private List<dbf_DomainBuilderStory> m_stories = new List<dbf_DomainBuilderStory>();

    /*
     *  the first builder executed in the chain of stories
     *  used to initiate .persist() and .build() across all registered builders
     */
    private dbf_IDomainBuilder prime = null;

    /*
     *  keeps track of each story's initialization status
     */
    private Boolean initialized = false;

    // REGION END: PROPERTIES ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||



    // REGION START: PROTECTED METHODS |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||

    /**
     *  Processes narrative relationships to define discovery fields for all objects ahead of data population.
     *  Chains through related stories to perform the same function.
     *  Exits immediately if the process has already been executed.
     *  @return         Self, so allow for fluent chaining of methods.
     */ 
    protected dbf_DomainBuilderStory initialize() {
        if (initialized) { return this; }
        for(Narrator narrator : narrators()) {
            if (narrator.isStandalone) { continue; }
            for (Relation fam : narrator.relations) {
                try {
                    Type targetNarrative = fam.narrativeType;
                    dbf_DomainBuilderNarrative tmpNarrative = (dbf_DomainBuilderNarrative)targetNarrative.newInstance();
                    Type targetBuilder = tmpNarrative.builderType();
                    SObjectType targetSObject = tmpNarrative.sObjectType();
                    SObjectField targetField = fam.targetField;
                    dbf_DomainBuilder.mapDiscoverableField(targetSObject, targetField);
                } catch(Exception ex) {
                    System.debug('Error thrown when assigning discoverable fields for relationship: '+ex);
                    // ignoring, because it just means the relationship isn't mapped
                }
            }
        }
        for(dbf_DomainBuilderStory relatedStory : relatedStories()) {
            relatedStory.initialize();
        }
        initialized = true;
        return this;
    }

    // REGION END: PROTECTED METHODS |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||



    // REGION START: PUBLIC METHODS ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||

    /**
     *  Executes .build() across all assigned narratives
     *  @return         The 1st dbf_DomainBuilder in the stack of registered builders
     */ 
    public dbf_IDomainBuilder build() {
        initialize();

        buildRelatedStories();
        
        buildStandaloneNarrators();

        buildNarrators();

        return prime;
    }

    /**
     *  Persists data from all assigned narratives.
     *  Triggers .build() followed by the resulting dbf_DomainBuilder's .persist()
     */ 
    public void persist() {
        this.build().persist();
    }

    /**
     *  Returns data from all assigned narratives using IMockDB
     *  Triggers .build() followed by the resulting dbf_DomainBuilder's .mock()
     *  @return         An instance of dbf_IDomainBuilderMockDB containing all generated, prescribed data
     */ 
    public dbf_IDomainBuilderMockDB mock() {
        return this.build().mock();
    }

    /**
     *  Creates a dbf_DomainBuilderStory.Narrator which is used to manage a Narrative and its dbf_DomainBuilderStory.Relation relatives
     *  Defaults the Narrator to repeat only 1 time. Calling .totallingCountOf(##) can override this default.
     *  @return         An instance of a dbf_DomainBuilderStory.Narrator
     */ 
    public static Narrator narrate() {
        return new Narrator().totallingCountOf(1);
    }

    // REGION END: PUBLIC METHODS ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||



    // REGION START: PRIVATE METHODS |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||

    /*
     *  calls .build() on all related stories
     */
    private void buildRelatedStories() {
        for(dbf_DomainBuilderStory relatedStory : relatedStories()) {
            dbf_IDomainBuilder firstFromRelated = relatedStory.build();
            if (prime == null) { prime = firstFromRelated; }
        }
    }

    /*
     *  builds narratives that have no defined relationships
     */
    private void buildStandaloneNarrators() {
        for (Narrator narr : narrators()) {
            if (!narr.isStandalone) { continue; }
            Integer imax = narr.repeats;
            for (Integer i = 1; i <= imax; i++) {
                dbf_IDomainBuilder domBuilder = narr.build();
                if (prime == null) { prime = domBuilder; }
            }
        }
    }

    /*
     *  builds narratives that have a relation defined
     */
    private void buildNarrators() {
        for (Narrator narr : narrators()) {
            if (narr.isStandalone) { continue; }
            Integer imax = narr.repeats;
            for (Integer i = 1; i <= imax; i++) {
                dbf_IDomainBuilder domBuilder = narr.build();
                if (prime == null) { prime = domBuilder; }
            }
        }
    }

    // REGION END: PRIVATE METHODS |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||



    // REGION START: INNER CLASSES |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||

    /**
     *  Governs the usage & referential structure of a given dbf_DomainBuilderNarrative
     */ 
    public class Narrator {
       
        /**
         *  Type - the Narrative that is being managed by this Narrator
         */ 
        public Type narrative { get; private set; }

        /**
         *  List<dbf_DomainBuilderStory.Relation> - all Relation objects used to track parent or external id references
         */ 
        public List<dbf_DomainBuilderStory.Relation> relations { get; set; }  { relations = new List<dbf_DomainBuilderStory.Relation>(); }

        /**
         *  Integer - the number of times this narrative should execute .build()
         */ 
        public Integer repeats { get; private set; }

        /**
         *  Boolean - false if the current narrative has references defined
         */ 
        public Boolean isStandalone { get { return relations.isEmpty();} }

        /**
         *  Fluently defines the Type, or class, of the Narrative being governed
         *  @param      narrativeType       Type    The Type, as an instance of dbf_DomainBuilderNarrative, to produce/generate/build
         *  @return     The current instance of the narrator
         */ 
        public Narrator over(Type narrativeType) {
            narrative = narrativeType;
            return this;
        }

        /**
         *  Fluently defines the repeats for the dbf_DomainBuilderNarrative, IE: the number of times to .build()
         *  @param      times       Integer    The number of times to run the given Narrative. NOTE: Only succeeds if your narrative is built to run multiple times. 
         *  @return     The current instance of the narrator
         */ 
        public Narrator totallingCountOf(Integer times) {
            repeats = times;
            return this;
        }

        /**
         *  Fluently adds a relationship to a parent/external builder/sObject, using supplied Relation model
         *  @param      relative       dbf_DomainBuilderStory.Relation      A defined parent/external "relative" to apply to the given Narrative
         *  @return     The current instance of the narrator
         */ 
        public Narrator relate(dbf_DomainBuilderStory.Relation relative) {
            if (relative == null) { return this; }
            if (relations.contains(relative)) { return this; }
            relations.add(relative);
            return this;
        }

        /**
         *  Fluently adds a relationship to a parent/external builder/sObject, using arguments provided
         *  @param      localField          sObjectField    The local field which holds the relationship
         *  @param      targetNarrative     Type            The Narrative targetted by the relationship
         *  @param      targetField         sObjectField    The field to use for discovering the target
         *  @param      targetValue         Object          The value to use for discovering the target
         *  @return     The current instance of the narrator
         */ 
        public Narrator relate(sObjectField localField, Type targetNarrative, sObjectField targetField, Object targetValue) {
            dbf_DomainBuilderStory.Relation relative = new dbf_DomainBuilderStory.Relation()
                .onField(localField)
                .toNarrative(targetNarrative)
                .whereField(targetField)
                .hasValue(targetValue);
            relations.add(relative);
            return this;
        }

        /*
         *  detects if the builder is an instance of dbf_IDomainBuilderWrapper to accurately call setParent()
         */
        private void assignParent(dbf_IDomainBuilder child, SObjectField field, dbf_IDomainBuilder parent) {
            if (child instanceOf dbf_IDomainBuilderWrapper) {
                ((dbf_IDomainBuilderWrapper)child).setParent(field, parent);
            } else {
                child.setParent(field, parent);
            }
        }

        /*
         *  detects if the builder is an instance of dbf_IDomainBuilderWrapper to accurately call setReference()
         */
        private void assignReference(dbf_IDomainBuilder target, SObjectField relatedToField, SObjectField targetExternalIdField, Object externalIdTarget) {
            if (target instanceOf dbf_IDomainBuilderWrapper) {
                ((dbf_IDomainBuilderWrapper)target).setReference(relatedToField, targetExternalIdField, externalIdTarget);
            } else {
                target.setReference(relatedToField, targetExternalIdField, externalIdTarget);
            }
        }
        
        /**
         *  Establishes relationships and builds the attached dbf_DomainBuilder
         *  @return         The dbf_DomainBuilder constructed by the dbf_DomainBuilderNarrative's .build() command
         */ 
        public dbf_IDomainBuilder build() {
            dbf_IDomainBuilder thisBuilder = ((dbf_DomainBuilderNarrative)narrative.newInstance()).build();
            if (isStandalone) { return thisBuilder; }
            for(dbf_DomainBuilderStory.Relation fam : relations) {
                // this line is creating an empty builder, which produces an empty sobject into the stack of that type.
                // it's creating a bug. build a method chain outward that grants access to the sobjecttype without creating instances.
                SObjectType targetType = ((dbf_DomainBuilderNarrative)fam.narrativeType.newInstance()).sObjectType();
                DescribeFieldResult sourceInfo = fam.sourceField.getDescribe();
                DescribeFieldResult targetInfo = fam.targetField.getDescribe();
                dbf_IDomainBuilder discovered = dbf_DomainBuilder.discoverRelationshipFor(targetType, fam.targetField, fam.targetValue);
                if (discovered == null) { continue; }
                if (targetInfo.isExternalID()) {
                    assignReference(thisBuilder, fam.sourceField, fam.targetField, fam.targetValue);
                    continue;
                }
                assignParent(thisBuilder, fam.sourceField, discovered);
            }
            return thisBuilder;
        }
    }

    
    /**
     *  Governs a relationship between two dbf_DomainBuilderNarrative
     */ 
    public class Relation {
        
        /**
         *  The Class, or Type, of the dbf_DomainBuilderNarrative being linked to
         */ 
        public Type narrativeType { get; set; }
        
        /**
         *  The Field of the source Narrative that is linked to the target
         */ 
        public SObjectField sourceField { get; set; }
        
        /**
         *  The Field of the target Narrative being linked to
         */ 
        public SObjectField targetField { get; set; }
        
        /**
         *  The value used to discover or assign the target to the source
         */ 
        public Object targetValue { get; set; }

        /**
         *  Determines whether this Relation has enough information to establish a real relationship
         *  @return         True if enough data has been provided to establish a relationship
         */ 
        public Boolean isValid { get {
            return narrativeType != null
                && sourceField != null
                && targetField != null
                && targetValue != null;
        }}

        /**
         *  Fluently identifies the sourceField of the related child
         *  @param      value   SObjectField    The local field which holds the relationship
         *  @return     The current instance of the relation
         */ 
        public Relation onField(SObjectField value) {
            sourceField = value;
            return this;
        }

        /**
         *  Fluently identifies the narrativeType of parent narrative
         *  @param      value   Type            The Narrative, as an instance of dbf_DomainBuilderNarrative, targetted by the relationship
         *  @return     The current instance of the relation
         */ 
        public Relation toNarrative(Type value) {
            narrativeType = value;
            return this;
        }

        /**
         *  Fluently identifies the targetField on parent which child relates to
         *  @param      value   SObjectField    The field to use for discovering the target
         *  @return     The current instance of the relation
         */ 
        public Relation whereField(SObjectField value) {
            targetField = value;
            return this;
        }

        /**
         *  Fluently identifies the targetValue in targetField on parent which child relates to
         *  @param      value   SObjectField    The value to use for discovering the target
         *  @return     The current instance of the relation
         */ 
        public Relation hasValue(Object value) {
            targetValue = value;
            return this;
        }
    }
    
    /*
     *  Custom exception class for general Story exceptions
     */
    public class dbf_DomainBuilderStoryException extends Exception {}

    /*
     *  Custom exception class for general Narrator exceptions
     */
    public class dbf_DomainBuilderStoryNarratorException extends Exception {}

    // REGION END: INNER CLASSES |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
}