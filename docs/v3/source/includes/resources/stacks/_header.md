## Stacks

Stacks are the base operating system and file system that your application will execute in.
A stack is how you configure applications to run against different operating systems
(like Windows or Linux)
and different versions of those operating systems
(like Windows 2012 or Windows 2016).

An application's [lifecycle](#lifecycles) will specify which stack to execute the application in.
Buildpacks can also be associated with a particular stack if they contain stack-specific logic.
An application will automatically use buildpacks associated with the application's configured stack.

Stacks are not used for apps with a [Docker lifecycle](#docker-lifecycle).

Operators control stack availability through state management. The following states determine how a stack can be used:

*ACTIVE*: Default state. The stack is fully available for all operations.

*DEPRECATED*: The stack is nearing end-of-life. It remains fully functional,
but users should migrate to an ACTIVE stack.

*RESTRICTED*: A transitional state typically applied before deprecation or disabling.
New application creation is blocked; existing deployments continue to operate normally.

*DISABLED*: The stack has reached end-of-life. New application creation and restaging are prohibited. 
Running applications remain available.
