# Changelog
All notable changes to this project will be documented in this file.
The format is loosely based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/).

This project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## 1.26.0

### User-facing

#### Fixed

- #632 remove unused files from package [temikus]
- #643 update disk attachment method to use new attached_disk_obj method [geemus]
- #644 improve mock bucket name regex validation [geemus]
- #646 fix frozen string literal warnings in storage [krororo]

### Development changes

#### Added

- #645 add ruby 3.3 and 3.4 to CI test matrix [krororo]

#### Fixed

- #641 Updated actions/checkout from 4 to 5 [dependabot]
- #642 Updated actions/stale from 9 to 10 [dependabot]
- remove stale workflow [geemus]

## 1.25.0

### User-facing

fog-core v2.2 and up now requires `Fog::Google:<service>` instead of `Fog::<service>::Google`.
There are shims in place that will provide backwards compatibility for the latter with
a deprecation warning, but you should update your code accordingly. The next major release
will drop support of the old format.

- #636 Support fog-core 2.5 and up [stanhu]

## 1.24.1

### User-facing

#### Fixed

- #629 Fix IAM scope for storage requests [stanhu]

## 1.24.0

### User-facing

#### Added

- #613 Spruce up attaching and detaching disks on running servers [rchekaluk]
- #621 Added support for discard_local_ssd when stopping an instance [rchekaluk]

### Development changes

#### Added

- #618 Deprecated Ruby-2.0 support [temikus]
- #624 Migrated the Integration tests to new ARC runners [temikus]
- #625 Fixed 'Ostruct' errors in storage tests [temikus]
- #627 Added concurrency groups to integration test workfows [temikus]

#### Fixed

- #604 Updated pry requirement from = 0.13.0 to = 0.14.2 [dependabot]
- #619 Updated google-cloud-env requirement from ~> 1.2 to >= 1.2, < 3.0 [dependabot]
- #620 Bump actions/stale from 8 to 9 [dependabot]
- #622 Updated fog-core requirement from < 2.3 to < 2.5 [dependabot]

## 1.23.0

### User-facing

#### Fixed

- #609 Fixed missing paging on all models [agrare]
- #608 Fixed `Fog::Compute::Google::Servers#all` paging [agrare]

### Development changes

#### Fixed

- #606 Use `Minitest::Test` instead of `MiniTest::Test` [chubchenko]
- #605 Bump actions/checkout from 3 to 4 [dependabot]
- #602 Bump actions/stale from 6 to 8 [dependabot]

## 1.22.0

### User-facing

#### Added

- #600 - Add uniform attr to inserting file [cwjenkins]

### Development changes

#### Fixed

- #601 Remove deprecated ruby versions from unit tests [temikus]

## 1.21.1

### User-facing

#### Fixed

- \#597 loosen dependencies to avoid conflict

### Development changes

#### Fixed

- bump actions/checkout from 2.4.0 to 3.1.0
- fixes and refinements for integration tests

## 1.21.0

### User-facing

#### Fixed

- \#592 use Addressable for escaping paths when generating urls
- test workflow refinements

### Development changes

#### Fixed

- bump actions/checkout from 2.4.0 to 3.1.0
- fixes and refinements for integration tests

## 1.20.0

### User-facing

#### Fixed

- update google client dependencies
- \#591 only create new RSA keys if needed for faster signing

### Development changes

#### Fixed

- bump actions/checkout from 2.4.0 to 3.1.0
- fixes and refinements for integration tests

## 1.19.0

### User-facing

#### Fixed

- \#561 Add ruby 3.1 to testing
- \#566 remove execute permission from network.rb
- \#571 replace Proc.new usage for Ruby 3

## 1.18.0

### User-facing

#### Fixed

- \#556 Correct conflicting Ruby version info in readme [gdubicki]
- \#557 Update current images projects list [gdubicki]
- \#558 Fix page iteration when using #files with block [jgigault]
- \#562 Loosen fog-core dependency

## 1.17.0

### User-facing

#### Added

- \#550 Add support for instance display device [dcode]

## 1.16.1

### User-facing

#### Fixed

- \#545 Avoid duplicate GET requests when retrieving body [stanhu]
- \#547 Remove exec bit from non_scripts [kbrock]

## 1.16.0

### User-facing

#### Fixed

- \#540 Bring back integration tests for Fog-Google and fix an array of small bugs/regressions [temikus]

### Development changes

#### Added

- \#532 Add Truffleruby head to CI [gogainda]

## 1.15.0

### User-facing

#### Fixed

- \#534 Fix get_object not working with binary files [stanhu]

## 1.14.0

### User-facing

#### Added

- \#520 Support passing object properties to #copy_object [mshibuya]

#### Fixed

- \#530 Unescape slashes in urls [krokodaxl]

- \#528 Fix Ruby 3.0 kwargs error in `#copy_object` [deeeki]

- \#521 Unlink file temp file immediately [stanhu]

- \#527 \#523 Fix Ruby 3.0 kwargs failures [stanhu]

### Development changes

#### Fixed

- \#525 - Bump actions/checkout from 2 to 2.3.4

- \#524 - Bump actions/stale from 3 to 3.0.18


## 1.13.0

### User-facing

### Fixed

fix deprecated URI.escape usage to support Ruby 3.0
fix apply_client_options def to support Ruby 3.0

### Development Changes

Add github actions config and dependabot
Drop travis usage

### Added

## 1.12.1

### User-facing

#### Fixed

\#513 - support passing other request options `StorageJSON#copy_object` [yosiat]

### Development changes

#### Added

\#514 - Update .travis.yml to support PPC architecture testing [nageshlop]


## 1.12.0

### User-facing

#### Added

- \#509 Add ShieldedInstanceConfig support to `Server#insert` [lcy0321]

#### Fixed

- \#508 Fix GoogleXML::File#save incorrectly passing body to headers [stanhu]

- \#506 Add Trufferuby head to CI [gogainda]

### Development changes

#### Fixed

- \#510 Upgrade CI docker image to Ubuntu 18.04 [temikus]


## 1.11.0

### User-facing

#### Added

- \#503 - Add fallback URL signing mechanism via IAM SignBlob API [temikus]

#### Fixed

- \#498 Add `:idempotent` flag to Fog::Storage::GoogleXML::Real#head_object, fixing
          `Excon::Error::Socket: end of file reached (EOFError)` in certain scenarios, see \#416 [temikus]
- \#500 Set default options automatically if missing in `Pubsub#pull_subscription`

### Development changes

#### Fixed

- \#501 DRY'ed up the retry methods in monitoring tests [temikus]
- \#500 Cleanup unneeded constants in Server model, fix flaky PubSub tests [temikus]

## 1.10.0

### User-facing

#### Added

- \#480 Add label support to `Disk` model [militarpancho]
- \#485 Add a `Server#set_server_machine_type` request [gscho]
- \#490 Add RHEL SAP cloud image project [kgaikwad]
- \#491 Add `exclude_projects` option to exclude any global project [kgaikwad]
- \#495 Add support to perform Windows passwords reset procedure through Fog [dvanbrug]

#### Fixed
- \#455 Fix metadata format for `Server#add_ssh_key()` [kgaikwad]
- \#452 Fix `Address.{associate,disassociate}` methods [temikus]
- \#486 Fix `Monitoring#create_time_series` method [temikus]
- \#493 Add sync/async support to `Google::SQL::SslCert` model init [temikus]

### Development changes

#### Added

- \#474 Added a manually-triggered pipeline to build from HEAD [temikus]
- \#470 Added tests for `Server#add_ssh_key()` [kgaikwad]
- \#461 Added dependabot integration [temikus]
- \#458 Add SECURITY.md, outlining the lib security policy [icco]
- \#457 Added Ruby 2.6 to travis, switch to default distro [icco]
- \#453 Implemented worker-side caching of dependencies between jobs [temikus]
- \#452 Increase `Address` model test coverage [temikus]

#### Fixed

- \#469 Zone/Monitoring test logging/style improvements [icco]
- \#465 Stopped counting non-implemented mocks in code coverage [temikus]
- \#463 Fixed SQL tests broken by the API change [temikus]
- \#476 Re-enabled Stackdriver pagination tests [temikus]
- \#488 Tiny fix to ssh key tests to remove a race condition [temikus]
- \#493 Removing SQLv1 API support from tests [temikus]

## 1.9.1

### User-facing

#### Fixed

- \#448 Add `:google_application_default` as recognized argument in
  Fog::Compute::Google client [mavin]

### Development changes

#### Added

- \#449 Add a helper rake task to populate changelog [temikus]

## 1.9.0

### User-facing

#### Added

- \#442 Add support for Application Default credentials [mavin]
  - This change allows the use of Application Default Credentials so that end
    users can authenticate without a service account for development, testing,
    and one-off interactions by using `:google_application_default`client
    option. See README for more details.

### Fixed

- \#444 Remove deprecated `google_client_email` option from client parameters
  [temikus]
- \#446 Updating service parameters to avoid "unrecognised parameter" warnings
  when initializing Fog client with application default auth [temikus]

### Development changes

#### Fixed

- \#441 Update CI pipeline to Concourse V4 [temikus]
- \#444 Rework client authentication workflow [temikus]
  - Separate different auth streams into private helper methods
  - Add a fallback auth option - Google Application Default credentials
  - Minor fixes and performance optimizations

## 1.8.2

### User-facing

#### Added

- \#435 Added additional examples for attached disks usage. [temikus]

#### Fixed

- \#433 Allow the api to close Tempfiles inline, improving disk utilization.
        [itopalov]

### Development changes

#### Added

- \#425 Integration on Jruby + disk snapshot tests: [temikus]
  - Adding JRuby 9.1 into Travis
  - Added integration tests for disk snapshots

#### Fixed

- \#432 Relax fog-json constraint to minor version. [pravi]

- \#425 Miscellaneous dev improvements around JRuby and disk handling: [temikus]
  - Fix bundling in development environment on JRuby
  - Remove EOL versions of ruby from Travis
  - Consolidated logic of `Disk.get_as_boot_disk` and increase doc coverage of
    disk-associated methods.
  - Add a guard a guard method for `Snapshot.add_labels`

## 1.8.1

### User-facing

#### Fixed

- \#428 Relax fog-core lower version constraint for ManageIQ [temikus]

## 1.8.0

### User-facing

#### Added
- \#418 Reintroduce client options for proxy support, etc. [AlexanderZagaynov]

#### Fixed

- \#419 Locked down fog upstream dependencies to alleviate deprecation warnings
  until they can be properly dealt with. [temikus]
- \#400 Small `%Collection%.get` and `%Collection%.all` behaviour fixes [temikus]
  - `Fog::Google::SQL::Instances.get(nil)` no longer returns an invalid
    `sql#instancesList` object.
  - `Fog::Compute::Google::InstanceGroups.get` and `.all` methods now support
    more than just `:filter` option, fixed `.all` output without `zone` option.
  - Fix a typo causing `Operations.get(region:REGION)` to fail.
  - `Fog::Compute::Google::Images.get(IMAGE, PROJECT)`, now returns `nil` if
    image is not found rather than throwing `Google::Apis::ClientError`.

### Development changes

#### Added

- \#400 Additional test coverage [temikus]
  - Expanded tests for `%Collection%.get` behavior - scoped requests
    (e.g. `get(zone:ZONE)`) and their corresponding code paths are now also
    properly tested.
  - Increase `Fog::Compute::Google::Images` integration test coverage.
  - Unit tests now work without a `~/.fog` config file set up.
  - Expanded unit test coverage.
- \#424 Add simple integration tests to check client proxy options being
  applied.

#### Changed

- \#400 Refactored most compute `get()` and `all()` methods to common format. [temikus]

#### Fixed

- \#400 Removed the Travis Ruby 2.5 workaround. [temikus]

## 1.7.1

### User-facing

#### Fixed

- \#412 Fixed `Fog::Storage::GoogleXML::GetObjectHttpUrl#get_object_http_url`
  request

## 1.7.0

### User-facing

#### Added

- \#409 Support query parameters in `Fog::Storage::Google` GET requests [stanhu]
- \#394 Add some helper methods to `Fog::Compute::Google::Server` [temikus]
  - `.private_ip_address`
  - `.stopped?`
- \#375 Add timeout options to `Fog::Storage::GoogleJSON` client [dosuken123]

#### Changed

- \#394 `save/update/destroy` and other operations now wait until they are in a
  DONE state, instead of !PENDING. This should be a no-op for users but should
  safeguard from issues in the future. [temikus]
- \#383 `Fog::Compute::Google::Address` resources are now created synchronously
  by default. [temikus]

### Development changes

#### Added

- \#409 Expand `Fog::Storage::Google` unit tests [stanhu]
- \#370 Introducing test coverage back, integrating with codecov.io [temikus]
- \#373 Increase integration test coverage. [temikus]
  - Add Firewall factory and tests.
  - Add InstanceGroup factory and tests.
  - Add MachineType tests.
- \#376 Add doc coverage tracking. [temikus]
- \#383 Increase integration test coverage further. [temikus]
  - Add collection tests and factories (when mutable) for following resources:
    - Addresses
    - Disks
    - Projects
    - Routes
    - Operations
    - Networks
    - Subnetworks
  - Fix compute tests Rake task.
  - Remove old tests and helpers for Disk, Addresses and Networks.
- \#394 Improve `Server` model test coverage + miscellaneous improvements. [temikus]
  - Add source_image parameter to `DiskFactory` so the Servers factory creates
    properly running instances.
  - `CollectionFactory.cleanup` method is now cleaning up resources per-suite
    instead of using a global prefix.
  - Add new test formatter improving observability of CI logs.
  - Add debug logs to test.
  - Improve doc coverage.

## 1.6.0

### User-facing

#### Changed

- \#338 `Fog::Google::SQL` resources are now created and destroyed synchronously by default.
You can override it in a standard manner by passing a parameter to async method, e.g.:
 `Fog::Google::SQL::Instance.create(true)` [temikus]
- \#367 `Fog::Compute::Google::Server.bootstrap` changes [temikus]
  - Now creates instances with disks that automatically delete on instance shutdown.
  - Now creates instances with a public IP address by default.

#### Added

- \#361 `Fog::Compute::Google::Server` now recognises `network_ip` attribute to specify internal IP. [mattimatti]

#### Fixed

- \#338 Fixed SQL Users model workflow [temikus]
- \#359 Fix whitespace escaping in XML Storage methods [temikus]
- \#366 Fixing `Server` model to properly accept `:private_key_path` and `:public_key_path` attributes again. [temikus]
- \#367 `Fog::Compute::Google::Server.bootstrap` parameters are now properly merged with default ones. [tesmikus]

### Development changes

#### Added

- \#338 Major refactor of SQLv1 and SQLv2 tests + a lot of small test fixes/improvements
   (see PR/commit messages for full set of changes) [temikus]

#### Fixed

- \#363 Fixed flaky Monitoring tests [temikus]

## 1.5.0

### User-facing

- \#348 Added Instance Group Manager and Instance Templates [bpaquet]

  - `Fog::Compute::Google::InstanceGroupManager` model and associated requests:
    - `:get_instance_group_manager`
    - `:insert_instance_group_manager`
    - `:delete_instance_group_manager`
    - `:list_instance_group_managers`
    - `:list_aggregated_instance_group_managers`
    - `:recreate_instances`
    - `:abandon_instances`

  - `Fog::Compute::Google::InstanceTemplate` model and associated requests:
    - `:list_instance_templates`
    - `:get_instance_template`
    - `:insert_instance_template`
    - `:delete_instance_template`
    - `:set_instance_template`

#### Fixed

- \#356 Hotfix - removing buggy deprecated 'google-containers' project, causing 403 errors
  on `images.all` call. [tumido]

### Development changes

#### Added

- \#350 Added InstanceGroupManager and InstanceTemplate integration tests [temikus]

## 1.4.0

### User-facing

#### Added

- \#336 `Fog::Compute::Google::Server.set_metadata` is now working properly and adopted a simpler format, e.g. `{'foo' => 'bar', 'baz'=>'foo'}`
- \#334 Added a new helper method: `Fog::Compute::Google::Server.public_ip_address` [temikus]
- \#314 Added `Fog::Compute::Google::InstanceGroup.add_instance` method back [temikus]
- \#326 Added support for using predefined ACLs, refactor valid ACLs [vimutter]
- \#318 Added fog_public support in Storage JSON API [jayhsu21]

#### Fixed

- \#354 Bump Google API client to 0.23 [temikus]
- \#346 Fixed get_health when called with an instance name [bpaquet]
- \#317 Fixed source_image selection to get the image from name if the format is not compatible with new Google API Client [temikus]
- \#321 Fix string key instead of symbol for subnetworks listing [tumido]
- \#351 Fixed trailing spaces and added data presence check to `Fog::Storage::GoogleJSON.put_object` [vimutter]

### Development changes

#### Added

- \#353 Added collection/model unit tests to be run by Travis CI [temikus]
- \#347 Added target pool tests [temikus]

#### Fixed

- \#322 Fixed all broken integration tests, all tests now pass in CI [temikus]
- \#344 Updated CI pipeline to run in parallel, broke out test tasks [temikus]

## 1.0.1

\#290 - Fixes paperclip integration
\#288 - Fixes typo in server network code

## 1.0.0

1.0.0!!!!!!!!!!!!

This rewrites everything except for the legacy storage backend!

Shoutout to @emilymye, @Temikus, @DawidJanczak, @Everlag and everyone who has been asking for this for ~forever.

We did this major refactor because as of version 0.9, google-api-client rewrote their entire api, thus limiting our ability to integrate with google APIs, and also running into a bunch of deprecated gem collisions.

You no longer need to require google-api-client, we are now doing that for you.

HELP: We need help testing. Please report bugs! As this is a complete rewrite of the request layer, there are undoubetedly bugs. We had to throw away most of our tests, and due to the time this has taken us, we chose to ship, instead of writing tests for everything all over again. If you would like to write tests, we would love your PRs, as well as any ideas you have about how we can test this code better.

Thanks!

## 0.6.0

NOTE: New Monitoring models are not compatible in any way to old ones because of significant rewrite to monitoring api since v2beta2.

## 0.5.5

Adds support for SSL certificates, https proxies and global IP addresses: #244

## 0.5.4

Fixes a storage bug #224 and fixes an issue with compute snapshots #240

## 0.5.3

Fixes a bunch of bugs and adds subnetworks support.

PRs that change functionality: #212, #215, #203, #198, #201, #221, #222, #216

## 0.5.2

Rapid-releasing 0.5.2 due to regression fixed by #190 still present in v0.5.1
We encourage people using 0.5.1 to upgrade.

## Template to use

### User-facing

#### Changed

#### Added

#### Fixed

### Development changes

#### Added

#### Fixed
