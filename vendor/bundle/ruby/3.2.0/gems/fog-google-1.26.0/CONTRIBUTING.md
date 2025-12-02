# Getting Involved

New contributors are always welcome, and when in doubt please ask questions!
We strive to be an open and welcoming community. Please be nice to one another.

We recommend heading over to fog's [CONTRIBUTING](https://github.com/fog/fog/blob/master/CONTRIBUTING.md)
and having a look around as well.  It has information and context about the state of the `fog` project as a whole.

### Coding

* Pick a task:
  * Offer feedback on open [pull requests](https://github.com/fog/fog-google/pulls).
  * Review open [issues](https://github.com/fog/fog-google/issues) for things to help on,
    especially the ones [tagged "help wanted"](https://github.com/fog/fog-google/issues?q=is%3Aissue+is%3Aopen+label%3A%22help+wanted%22).
  * [Create an issue](https://github.com/fog/fog-google/issues/new) to start a discussion on additions or features.
* Fork the project, add your changes and tests to cover them in a topic branch.
  * [Fork](https://github.com/fog/fog-google/fork)
  * Create your feature branch (`git checkout -b my-new-feature`)
  * Commit your changes (`git commit -am 'Add some feature'`)
  * Push to the branch (`git push origin my-new-feature`)
  * Create a new pull request
* Commit your changes and rebase against `fog/fog-google` to ensure everything is up to date.
* [Submit a pull request](https://github.com/fog/fog-google/compare/)

### Non-Coding

* Offer feedback or triage [open issues](https://github.com/fog/fog-google/issues).
* Improve documentation. See project's [inch tracker](https://inch-ci.org/github/fog/fog-google.svg?branch=master)
  for ideas for where to get started.
* Organize or volunteer at events.

## Contributing Code

This document is very much a work in progress.  Sorry about that.

It's worth noting that, if you're looking through the code, and you'd like to know the history of a line,
you may not find it in the history of this repository, since most of the code was extracted from [fog/fog](https://github.com/fog/fog).
So, you can look at the history from commit [fog/fog#c596e](https://github.com/fog/fog/tree/c596e710952aa9c90713da3fbfb3027db0608413)
backward for more information.

### Development environment

If you're going to be doing any kind of modifications, we highly recommend using [rbenv](https://github.com/sstephenson/rbenv),
[ruby-build](https://github.com/sstephenson/ruby-build), (don't forget the [dependencies](https://github.com/sstephenson/ruby-build/wiki#suggested-build-environment)!)
and [bundler](http://bundler.io/).

Once you've got that all installed, run

```shell
$ bundle install
```

to install the required gems.  You might have to [fight a bit](http://www.nokogiri.org/tutorials/installing_nokogiri.html)
to get Nokogiri installed.

Then, you should be ready to go!  If you'd like to drop into an interactive shell, configured with your `:default` credential, use

```shell
$ rake console
```

### Documentation

Code should be documented using [YARDoc](https://yardoc.org/) syntax.
We use [inch](https://github.com/rrrene/inch) to keep track of overall doc
coverage and [inch-ci](https://inch-ci.org/) to keep track of changes over time.

You can view a doc coverage report by running:
```
$ inch
```

Or view suggestions on a specific method:
```
$ inch show Fog::Google::Compute::Server#set_metadata
```

### Testing

This module is tested with [Minitest](https://github.com/seattlerb/minitest).

#### Integration tests

Live integration tests can be found in `test/integration/`.

Most of the library functionality is currently covered with them. To simplify things for contributors we have a
CI system that runs all integration tests in parallel against all pull requests marked with `integrate` label
that anyone in `fog-google` team can set. Read [CI section](https://github.com/fog/fog-google/blob/master/CONTRIBUTING.md#continuous-integration)
for more info.

After completing the installation in the README, (including setting up your credentials and keys,)
make sure you have a `:test` credential in `~/.fog`, something like:

```
test:
  google_project: my-project
  google_json_key_location: /path/to/my-project-xxxxxxxxxxxxx.json
```

Then you can run all the live tests:

```shell
$ bundle exec rake test
```

or just one API:

```
$ bundle exec rake test:compute
```
(See `rake -T` for all available tasks)

or just one test:

```shell
$ bundle exec rake test TESTOPTS="--name=TestServers#test_bootstrap_ssh_destroy"
```

or a series of tests by name:

```
$ bundle exec rake test TESTOPTS="--name=/test_nil_get/"
```

#### Unit tests

Some basic sanity checking and logic verification is done via unit tests located in `test/unit`.
They automatically run against every pull request via [Travis CI](http://travis-ci.org/).

You can run unit tests like so:

```
$ rake test:unit
```

We're in progress of extending the library with more unit tests and contributions along that front are very welcome.

#### The transition from `shindo` to Minitest

Previously, [shindo](https://github.com/geemus/shindo) was the primary testing framework.
We've moved away from it, and to Minitest, but some artifacts may remain.

For more information on transition, read [#50](https://github.com/fog/fog-google/issues/50).

#### Continuous integration

Currently Google maintains a [Concourse CI](https://concourse-ci.org/) server, running a pipeline defined in `ci` folder.
It automatically runs all integration tests against every pull-request marked with `integration` label.

For more information on the pipeline please refer to the [ci README](https://github.com/fog/fog-google/blob/master/ci/README.md).

#### Some notes about the tests as they stand

The live integration tests for resources, (servers, disks, etc.,) have a few components:

- The `TestCollection` **mixin module** lives in `test/helpers/test_collection.rb`
and contains the standard tests to run for all resources, (e.g. `test_lifecycle`).
It also calls `cleanup` on the resource's factory during teardown, to make sure
that resources are getting destroyed before the next test run.
- The **factory**, (e.g. `ServersFactory`, in `test/integration/factories/servers_factory.rb`,)
automates the creation of resources and/or supplies parameters for explicit
creation of resources.  For example, `ServersFactory` initializes a `DisksFactory`
to supply disks in order to create servers, and implements the `params` method
so that tests can create servers with unique names, correct zones and machine
types, and automatically-created disks.  `ServersFactory` inherits the `create`
method from `CollectionFactory`, which allows tests to create servers on-demand.
- The **main test**, (e.g. `TestServers`, in `test/integration/compute/test_servers.rb`,)
 is the test that actually runs.  It mixes in the `TestCollection` module in
 order to run the tests in that module, it supplies the `setup` method in which
 it initializes a `ServersFactory`, and it includes any other tests specific to
 this collection, (e.g. `test_bootstrap_ssh_destroy`).

If you want to create another resource, you should add live integration tests;
all you need to do is create a factory in `test/integration/factories/my_resource_factory.rb`
and a main test in `test/integration/compute/test_my_resource.rb` that mixes in `TestCollection`.
