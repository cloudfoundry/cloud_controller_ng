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

