VCAP Cloud Controller Design
============================

Overview
--------
This version of the Cloud Controller is being redone from the ground up. While
we are generally not in favor of wholesale rewrites of components and prefer to
refactor in place, this is somewhat difficult with the previous CC code base
for a few reasons.  1) the rest of CF uses Sinatra rather than Rails and we
want to unify our http framework, 2) we are converging on Sequel rather than
Active Record for our ORM, so we want to unify this in the CC, 3) the previous
CC used hybrid event/fiber based concurrency model that cause a lot of issue
with developers accidentally blocking the event loop.  While I'm generally in
favor of evented and/or fiber based systems when running at high levels of
concurency, the CC does not fit that usage pattern, so the trade offs are not
worth it.  A thread per request is perfectly fine for the CC and avoids having
to worry about eventloop blocking issues.

It should be noted that while what is left of the previous CC is now going
through a rewrite, we have actually been somewhat doing a refactoring in place
since the initial release.  We wanted to move staging, auth/authz, and resource
managment out of the CC. That happened in the context of the previous CC and
major sections of CC code were turned off.  The remaining app state management
of the CC is the focus of this rewrite.

High Level Architecture
-----------------------
The high level architecture of this version of the CC can be sumarized as
follows:

* Sinatra HTTP framework.
* Sequel ORM
* Thread per request (currently using Thin in threaded mode)
* NATS based communication with other CF components

Performing NATS communication in a threaded model requires an adapter between
concurrency models.  This is done by adding an EventMachine#schedule_sync method
which is run on a thread other than the reactor thread, i.e. a thread for a
request or some other worker thread pool, and runs the provided block in the
reactor thread.  It blocks the calling thread on the result and will return the
result of the block or re-throw an exception if the calling thread if
necessary.
