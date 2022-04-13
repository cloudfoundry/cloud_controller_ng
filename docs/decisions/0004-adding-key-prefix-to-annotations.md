4: Adding key prefix to annotations
================================

Date: 2019-06-11

Status
------

Accepted


Context
-------

Kubernetes has modified their [definition of annotations](https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/) to support separate key prefixes and key names.
This update makes annotation keys behave the same as [label](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/) keys.

Key prefixes can be up to 253 characters long and must be valid DNS names.
Key names can be up to 63 characters long and can contain alphanumeric characters plus some limited punctuation.
See [these docs](http://v3-apidocs.cloudfoundry.org/version/3.72.0/index.html#labels-and-selectors) for more information on label key requirements.

When we implemented annotations as part of the [metadata epic](https://www.pivotaltracker.com/epic/show/4124692) these restrictions did not exist.
Since annotations are not queryable on the API, we allowed users to create annotations with keys up to 1000 characters long and we did not limit the allowed character set.

API clients [such as service brokers](https://github.com/openservicebrokerapi/servicebroker/issues/654) would like a consistent interface for annotations in both CF and Kubernetes,
so we are planning on adding the concept of label key prefixes/names to annotations in [#166447964](https://www.pivotaltracker.com/story/show/166447964).

This was first brought to us in the following Github issue: [#1335](https://github.com/cloudfoundry/cloud_controller_ng/issues/1335)

This leaves us with two problems:
1. How do we model annotation keys going forward?
2. How do we handle existing annotations that do not conform to these restrictions?

Decision
--------

1. Make the table structure for annotations more closely match the schema for labels
    * Add a `key_prefix` column to annotations
    * Leave the `key` column name the same for rolling-deployment compatibility, but treat it as if it was `key_name`
    * Leave the `key` column size the same (1000 characters) for backward compatibility. We will enforce the 63 character limit on the Ruby side in validations.
    * Do this in separate migrations for each annotation table to avoid deadlocking during the upgrade.
    * In the Ruby code alias `key` to `key_name` in the methods we use to talk to it.
    * Create a [time bomb test](https://github.com/cloudfoundry/cloud_controller_ng/blob/b6ba5196722728a221034aadad076646f43f5de3/spec/support/deprecation_helpers.rb) to tell us to rename the column in six months
1. New annotations will be stored with the key split between `key_prefix` and `key_name` (`key` column)
1. Updated annotations will be stored with the key split between `key_prefix` and `key_name` (`key` column)
1. Updating annotations that do not meet the new prefix validations will fail with a `422` error
1. Existing annotations will continue to be readable until they are updated. Since they are not queryable this should not cause too much overhead.

We **will not** attempt to migrate existing data into this new structure for the following reasons:

1. Migrations fail when Cloud Foundry is being upgraded and a failed migration is difficult for operators to recover from. We do not want to risk platform downtime and support incidents.
1. The operator upgrading a platform is likely not the one who created (or "owns") the resource with the problematic annotations. Lazily migrating annotations when they are updated ensures that the one who owns it gets to make the decision.

Consequences
------------

### Positive Consequences
1. We will be aligned with Kubernetes once more. 🙂
1. We will have a more consistent schema across labels and annotations.
1. By separating `key_prefix` from `key_name` we will not preclude ourselves from adding new features that want to use or query on the prefix independently.

### Negative Consequences
1. Users who were relying on large annotation keys will be upset we took them away from them. 😔
1. We will be performing migrations across many different tables, there is still the potential for upgrade issues.
1. Lazily updating annotations means some will have the old structure for a long time.
