## Environment Variable Groups

There are two types of environment variable groups: running and staging. They are designed to allow platform operators/admins to manage environment variables across all apps in a foundation.

Variables in a **running** environment variable group will be injected into all **running app containers**.

Variables in a **staging** environment variable group will be injected into the **staging container** for all apps while they are being staged.
