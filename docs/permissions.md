# Permissions

The following is cut/paste from a doc received from Ilia describing
the various permissions.

## The org permissions:

### Org manager
The org-admin permission is used to edit the ACL on the org.
As such an org-admin can set herself as someone with billing-admin rights, or
she can decide to keep this as something that is strictly reserved for finance.
we don't protect against this as we do not consider this an elevation of
privilege. The org-admin permission is required in order to create or delete an
app-space, the enumerate app-spaces, to purchase/read/write/manage org-level
features, to change the plan for an org, to invite/add users to the org, to
view all org level reports including usage reports, and to set/manage all
non-finance related notifications.

### Billing manager
The billing-admin permission is required in order to set
payment information, read invoices, read payment history, edit the invoice
notification email addresses as well as all other finance related
notifications, and set the org spending limit. this is strictly a financial
permission and gives the holder absolutely no other rights (e.g., she can not
create/delete app-spaces, edit acls, invite users, etc.). For rubicon, jared or
rodney would be the guys with this permission on each rubicon org.

### Org Audit
The org audit permission gives the user rights to see all org level
and app space level reports and also all org space level and app space level
events

## The app space permissions:

### App Space Manager
This permission is required to edit the acl on an app-space
(e.g., to add additional managers, to invite developers, etc.), and to
enable/disable/add "features" to the app-space which can then be used by
applications within the app-space. The canonical example of this is wildcard
sub-domains. The admin permission is required in order to enable
\*.my-domain.com on the app-space. Once this wildcard subdomain is added,
developers can create apps that live on this domain. the admin permission on an
app-space does not give one the ability to create or delete app-space's. This
function is considered to be an operation on the org object, so the code behind
"vmc create app-space" performs an access-check against the current/containing
org object.

### Developer
The developer permission is required in order to perform ALL
operations against apps and services within the app-space.I.e., the developer
permission is required to perform the following app operations: create, delete,
stop, change instance count, bind/unbind services, read logs and files, read
stats, enumerate apps, change app settings. It is also required to perform the
following service operations: create, delete, backup, restore, read logs,
enumerate services, change settings. If we were to map this to today's current
system, ALL users have the developer permission for their account (which is
identical to their single per-user app-space). The developer permission also
allows holders to read the app-space's spending limit as well as each app's
current usage/spend. This is the functionality a developer would use to insist
that the admin add more $$ to the app-space.

### App Space Audit
The audit permission is required to read all state from the
app-space and all containing apps. If all a user has is audit access, she can
do anything that is non-destructive. She can enumerate apps and services, read
all logs, files and stats from all apps and services within the space. This
permission does not allow any destructive operations and does not allow any
mutations. As a result, this permission can not be used to create a caldecott
tunnel as this would require a bind... Note, the audit permission is a subset
of the developer permission. This means a set of access-check calls that gate
these capabilities typically would perform its checks against
&p=developer,audit.
