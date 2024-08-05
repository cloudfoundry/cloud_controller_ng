## Revisions

Revisions represent code used by an application at a specific time. The most recent revision for a running application represents code and configuration currently running in Cloud Foundry. Revisions are not created for Tasks.

Revision are created when the following is changed:

* A new droplet is deployed for an app

* An app is deployed with new environment variables

* The app is deployed with a new or changed custom start command

* An app rolls back to a prior revision

Each time a new revision is created the reason(s) for the revisions creation will be appended to its description field.

By default the cloud foundry API retains at most 100 revisions per app.
