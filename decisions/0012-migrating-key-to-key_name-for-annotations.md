12: Adding key prefix to annotations
================================

Date: 2023-08-23

Status
------

Accepted

Context
-------

In our ADR-0004, the decision to align annotations with labels was made, while keeping in mind that no data migration should take place. However, following ADR-11, ensuring unique annotations mandated a data migration. This presented an opportunity to align the database layout for Annotations and Labels to remove any schema-wise differences. Specifically, this implies renaming the `key` column to `key_name`.

Decision
--------

1. Create a view for each annotation table aliasing the `key` column as `key_name` on the DB rather than the Model.
1. Modify our code, tests and model to rely on the view and the `key_name` column.
1. Rename the `key` column to `key_name` for each annotation table.
1. Remove the views on annotation tables.

It is important to note:

- Steps 1 and 2 are backward compatible with any CC version,
- Step 3 is only backward compatible with any CC version incorporating changes from steps 1 and 2,
- Step 4 is only backward compatible with any CC version featuring changes from step 3.

Consequences
------------

### Positive Consequences

1. Consolidation of the codebase for labels and annotations and the alignment of database table layouts. This will simplify and standardize the current setup which can be confusing due to the table aliases in the models.

### Negative Consequences

1. A staged rollout will be necessary requiring clear documentation about limitations on upgrade paths since we have two changes that necessitate a specific minimum CF-Deployment/CAPI version.