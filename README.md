Re-architecture & expansion of the original DomainBuilder by Robert Sosemann (https://twitter.com/rsoesemann):<br>
https://github.com/rsoesemann/apex-domainbuilder

Depends upon the following public repositories:<br>
https://github.com/financialforcedev/fflib-apex-common<br>
https://github.com/financialforcedev/fflib-apex-mocks

# Setup
Install Shane's SFDX plugin
sfdx plugins:install shane-sfdx-plugins

Setup teh scratch org
sfdx force:org:create -a dbf -f config/project-scratch-def.json 

Install the fflib-apex-mocks project
sfdx shane:github:src:install -g financialforcedev -r fflib-apex-mocks -u dbf

Install the fflib-apex-commons project
sfdx shane:github:src:install -g financialforcedev -r fflib-apex-common -p fflib/src -u dbf

Push the DBF source code
sfdx force:source:push -u dbf

# Apex / DX Domain Builder

Framework for constructing data, covering multiple use-cases of varying complexity. At their core, Domain Builders function as a mixture of Data Factory and Object Mother, depending upon implementation style and technique. Implementations can range from a simple Domain Builder per SObject providing internal Data Factory / Mother methods to complex, story-driven implementations which separate data concerns from business concerns and span the managed package boundary. The complexity of your use-case can dictate how involved your implementation needs to be. It is recommended that your approach err on the side of simplicity, only gaining the more complex features when necessary.

Your implementation could be as simple as creating individualized dbf_DomainBuilder implementations for each SObject you're creating data for, and convenience methods for each data variation. Or as complex as creating dbf_DomainBuilderStory implementations that call other Stories, each calling a series of related Narratives, each calling their own dbf_DomainBuilder and supplying the data related to the story they're trying to tell.

How complex your implementation ends up is up to you and the usage patterns that fit your org, and your needs. Please review the **Typical Implementation Patterns** section for more information on the patterns of use that are expected/supported by this library.


## Typical Implementation Patterns


### Domain Builders as Data Factories

In this **simple** implementation, the only components of this package that need be implemented or extended is the **dbf_DomainBuilder** class itself. Each SObject can be represented by one or more dbf_DomainBuilder implementations, to suit your needs. The resulting builders produce data that can be committed to the org through the **persist()** method, or returned as a unit test usable mock database through the **mock()** method.

For more details, including implementation examples, please review the *tests\simple\s_Example_t.cls* file and the supporting classes called therein.


### Domain Builders as Data Factories, Crossing the Managed Package boundary

The **simple-with-managed-packages** pattern covers the implementation of a **simple** use-case including the management of DomainBuilders that are present in an ISV's published Managed Package. For example, you may be consuming a Managed Package named AcmeUtils in your production org. AcmeUtils presents several global dbf_DomainBuilder implementations for the package's custom objects that your org wishes to make use of. This use-case covers this need through the use of **dbf_IDomainBuilderWrapper** implementations.

**dbf_IDomainBuilderWrapper** is designed to wrap, or embed, a builder that is external to your org's local code. Data assignments are passed to the external builder through the wrapper so that any rules or business logic that exist withing the external builder's code can function as normal. At the end of the data construction process, when **persist()** or **mock()** are executed, data sent through wrappers is *reclaimed* so that it can process through your local *Unit of Work* in a single transaction.

For more details, including implementation examples, please review the *tests\simple\with-managed-package\s_Example_WMP_t.cls* file and the supporting classes called therein.


### Story-Driven Domain Builders

The purpose of the **story-driven** pattern is to provide separation between business logic and data creation, and add more supporting features for relationship management to the process of data creation. This approach allows your **dbf_DomainBuilder** and **dbf_IDomainBuilderWrapper** implementations to be finalized and remain un-altered as your data narratives are adjusted to suit testing and support needs.

This allows conversations about your data needs to drive the creation and management of fairly simple, focused classes whos only responsibility is assigning values to an SObject, or listing a series of narratives to be executed as a collective story. This is accomplished through the addition of the **dbf_DomainBuilderStory** and **dbf_DomainBuilderNarrative** classes and their additional features.

A **dbf_DomainBuilderNarrative** is a single 'persona' or 'data concept' which relates to a single record in an sObject. For example, a Narrative may be constructed which executes a User DomainBuilder to create a user sObject record for someone named John Smith. That Narrative would always, and only, create a record for John Smith through that User DomainBuilder, and would do nothing else. The DomainBuilder behind it would have no concept of John Smith whatsoever, and would only provide standardized, generic and default functionality which any dbf_DomainBuilderNarrative could make use of.

A **dbf_DomainBuilderStory** identifies a series of narrative implementations and their relationships which should all be constructed as a cohesive unit, represening a collection of data that may span many records across many sObjects, including the definition of the references between these sObjects. Moreover, stories can list and therefore cause the execution of other related stories.

For more details, including implementation examples, please review the *tests\story-driven\sd_Example_t.cls* file and the supporting classes called therein.


### Story-Driven across the Managed Package boundary

The most complex of all patterns, this approach combines the techniques of **"Domain Builders as Data Factories across the Managed Package boundary"** and **"Story-Driven Domain Builders"**. This approach encapsulates builders that reside within managed packages, and abstracts the business logic from your data concerns. In complex environments, it offers the greatest flexibility and sustainability.



## Advanced Techniques & Concerns

The Domain Builder suite covers a lot of ground when it comes to data creation and insertion. It attempts to cover the most common concerns an implementation team might have, including discovery of pre-existing data, referencing sObjects loosely by external Id, mocking of data rather than insertion for the purposes of unit test development and assignment of data to things like formula fields.

### Discovery of Pre-existing Data

When creating data for unit tests, automated tests or attempting to back-fill baseline data into a new sandbox or scratch org a very serious concern is stepping on or colliding with data that might already exist in the org. During unit tests this can be less of a concern because, depending on how your tests are written they may be executing inside a bubble and be unable to see your org's data.

This is not the case when it comes to automated testing scenarios or populating data directly into the org. Moreover, data in your org isn't the only place in which pre-existing data could be an issue. What if the dbf_DomainBuilder or Narrative your script, or Story, is asking for has already been created in memory by another part of the process. Should it be created twice, or should the system discover the pre-existing instance and utilize it?

The Domain Builder has a lot of logic built around the concepts of relationship management, and discovery of referenced objects. The key components being the use of methods such as discoverRelationshipFor() to find a parent Domain Builder rather than blindly constructing one. This is backed by the usage of setDiscoverableField() in your various Domain Builder implementations *(ideally in their constructor)* to instruct the system to watch the given fields for data, and build maps that let other builders or narratives discover those instances.

When it comes to data insertion, through the execution of Domain Builder's persist() method, the process gathers together all of the discoverable fields and mapped instances that were mapped during data creation and executes a series of SOQL statements to determine which, if any, already exist in your org. If any are discovered, it maps the Id value back to the respective sObject. This prevents insertion of records that already exist, and allows for the assignment of related sObjects before the underlying Unit of Work begins the commit process.


### Referencing sObjects by External Id

One of the more obscure techniques covered by this suite is the ability to assign relationships by external id. This is absolutely critical to some orgs, as referencing sObjects by external Id alleviates table locking issues cause by exhaustive use of master-detail references. The setReference() method provides the means to leverage this seldomly heard of feature.

This technique, however, cannot be unit tested in a default org. Default orgs do not have any references to External Id flagged fields. In fact, there are no fields on any sObjects in a default org that are *truly* External Id fields. No unit tests accompany this project which cover this feature. As such, please review the code comments in the file *tests\DomainBuilder_NonTestableExamples.cls* under the section labeled **REFERENCING BY EXTERNAL ID**.


### Mocking

Data can be created through Domain Builders, Narratives and/or Stories and mocked by simply calling **.mock()** rather than **.persist()**. The mock method returns an instance of **dbf_IDomainBuilderMockDB** which holds all of the data with generated Id values. It even handles dependencies within the mocked data, just as if it had been persisted to the Org and retrieved. 


### Formula Fields

Because the suite offers mocking functionality, it was critical to support insertion of formula field data. As many developers know, attempting to insert data into a formula field results in thrown exceptions. However, the **.set()** commands in Domain Builder account for that. When special fields, like formulas, are provided a value through them the Domain Builder shelves that value assignment. When **.mock()** is then called, the shelved values are pushed into those sObjects through *json magic*. This means that your mocked data can truly appear to have come straight from the Org. This also means that your *.persist()* data isn't sullied with data that can't be inserted. So, go ahead and add formula fields to your Narratives and reap the benefits when mocking during unit tests.


## TODO

1 - Finish this readme.
2 - SD WMP examples
3 - End-to-End full system test
4 - Fine-tuning of type conversions on list<Object> in DiscGraph
5 - Fine-tuning of discoverPreexisting process in DiscGraph to optimize SOQL usage


## Planned, Unimplemented Features

1 - Assignment of post-insert relationship values for edge-case sObject references
2 - Story-time assignment of Narrative field values
3 - Dynamic Story creation/management (via custom metadata)
4 - Dynamic Narrative creation/management (via custom metadata)
5 - Dynamic Story/Narrative UI (via LWC, using custom metadata)
