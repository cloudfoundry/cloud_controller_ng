require 'securerandom'
require_relative 'process_model_factory'
require_relative 'deployment_model_test_factory'
require_relative '../test_models'

Sham.define do
  email               { |index| "email-#{index}@somedomain.com" }
  name                { |index| "name-#{index}" }
  label               { |index| "label-#{index}" }
  token               { |index| "token-#{index}" }
  auth_username       { |index| "auth_username-#{index}" }
  auth_password       { |index| "auth_password-#{index}" }
  provider            { |index| "provider-#{index}" }
  port                { |index| index + 1000 }
  url                 { |index| "https://foo.com/url-#{index}" }
  type                { |index| "type-#{index}" }
  description         { |index| "desc-#{index}" }
  long_description    { |index| "long description-#{index} over 255 characters #{'-' * 255}" }
  version             { |index| "version-#{index}" }
  service_credentials { |index| { "creds-key-#{index}" => "creds-val-#{index}" } }
  uaa_id              { |index| "uaa-id-#{index}" }
  domain              { |index| "domain-#{index}.example.com" }
  host                { |index| "host-#{index}" }
  guid                { |_| SecureRandom.uuid.to_s }
  extra               { |index| "extra-#{index}" }
  instance_index      { |index| index }
  unique_id           { |index| "unique-id-#{index}" }
  status              { |_| %w[active suspended canceled].sample(1).first }
  error_message       { |index| "error-message-#{index}" }
  sequence_id         { |index| index }
  stack               { |index| "cflinuxfs-#{index}" }
end

module VCAP::CloudController
  %w[App Build Buildpack Deployment Domain Droplet IsolationSegment Organization Package
     Process Revision Route RouteBinding ServiceBinding ServiceKey ServiceInstance ServiceOffering ServiceBroker Space Stack
     ServicePlan Task User].each do |root|
    "VCAP::CloudController::#{root}LabelModel".constantize.blueprint {}
    "VCAP::CloudController::#{root}AnnotationModel".constantize.blueprint {}
  end

  IsolationSegmentModel.blueprint do
    guid { Sham.guid }
    name { Sham.name }
  end

  AppModel.blueprint do
    name       { Sham.name }
    space      { Space.make }
    buildpack_lifecycle_data { BuildpackLifecycleDataModel.make(app: object.save) }
  end

  AppModel.blueprint(:all_fields) do
    droplet_guid { Sham.guid }
    buildpack_cache_sha256_checksum { Sham.guid }
  end

  AppModel.blueprint(:kpack) do
    name { Sham.name }
    space { Space.make }
    buildpack_lifecycle_data { nil.tap { |_| object.save } }
    kpack_lifecycle_data { KpackLifecycleDataModel.make(app: object.save) }
  end

  AppModel.blueprint(:cnb) do
    name { Sham.name }
    space { Space.make }
    buildpack_lifecycle_data { nil.tap { |_| object.save } }
    cnb_lifecycle_data { CNBLifecycleDataModel.make(app: object.save) }
  end

  AppModel.blueprint(:docker) do
    name { Sham.name }
    space { Space.make }
    buildpack_lifecycle_data { nil.tap { |_| object.save } }
  end

  BuildModel.blueprint do
    guid     { Sham.guid }
    app      { AppModel.make }
    state    { VCAP::CloudController::BuildModel::STAGED_STATE }
  end

  BuildModel.blueprint(:docker) do
    guid     { Sham.guid }
    state    { VCAP::CloudController::DropletModel::STAGING_STATE }
    app { AppModel.make(droplet_guid: guid) }
    buildpack_lifecycle_data { nil.tap { |_| object.save } }
  end

  BuildModel.blueprint(:kpack) do
    guid     { Sham.guid }
    state    { VCAP::CloudController::DropletModel::STAGING_STATE }
    app { AppModel.make(droplet_guid: guid) }
    kpack_lifecycle_data { KpackLifecycleDataModel.make(build: object.save) }
    package { PackageModel.make(app:) }
    droplet { DropletModel.make(:docker, build: object.save) }
  end

  BuildModel.blueprint(:buildpack) do
    guid     { Sham.guid }
    state    { VCAP::CloudController::DropletModel::STAGING_STATE }
    app { AppModel.make }
    buildpack_lifecycle_data { BuildpackLifecycleDataModel.make(build: object.save) }
  end

  PackageModel.blueprint do
    guid     { Sham.guid }
    state    { VCAP::CloudController::PackageModel::CREATED_STATE }
    type     { 'bits' }
    app { AppModel.make }
    sha256_checksum { Sham.guid }
  end

  PackageModel.blueprint(:docker) do
    guid     { Sham.guid }
    state    { VCAP::CloudController::PackageModel::READY_STATE }
    type     { 'docker' }
    app { AppModel.make }
    docker_image { "org/image-#{Sham.guid}:latest" }
  end

  DropletModel.blueprint do
    guid { Sham.guid }
    process_types { { 'web' => '$HOME/boot.sh' } }
    state { VCAP::CloudController::DropletModel::STAGED_STATE }
    app { AppModel.make(droplet_guid: guid) }
    droplet_hash { Sham.guid }
    sha256_checksum { Sham.guid }
    buildpack_lifecycle_data { BuildpackLifecycleDataModel.make(droplet: object.save) }
  end

  DropletModel.blueprint(:all_fields) do
    execution_metadata { 'some-metadata' }
    error_id { 'error-id' }
    error_description { 'a-error' }
    staging_memory_in_mb { 256 }
    staging_disk_in_mb { 256 }
    buildpack_receipt_buildpack { 'a-buildpack' }
    buildpack_receipt_buildpack_guid { Sham.guid }
    buildpack_receipt_detect_output { 'buildpack-output' }
    docker_receipt_image { 'docker-image' }
    package_guid { Sham.guid }
    build_guid { Sham.guid }
    docker_receipt_username { 'a-user' }
    sidecars { 'a-sidecar' }
  end

  DropletModel.blueprint(:cnb) do
    guid { Sham.guid }
    droplet_hash { nil }
    sha256_checksum { nil }
    state { VCAP::CloudController::DropletModel::STAGED_STATE }
    app { AppModel.make(:cnb, droplet_guid: guid) }
    cnb_lifecycle_data { CNBLifecycleDataModel.make(droplet: object.save) }
    buildpack_lifecycle_data { nil.tap { |_| object.save } }
    kpack_lifecycle_data { nil.tap { |_| object.save } }
  end

  DropletModel.blueprint(:docker) do
    guid { Sham.guid }
    droplet_hash { nil }
    sha256_checksum { nil }
    state { VCAP::CloudController::DropletModel::STAGED_STATE }
    app { AppModel.make(droplet_guid: guid) }
    buildpack_lifecycle_data { nil.tap { |_| object.save } }
    kpack_lifecycle_data { nil.tap { |_| object.save } }
  end

  DropletModel.blueprint(:kpack) do
    guid { Sham.guid }
    droplet_hash { nil }
    sha256_checksum { nil }
    docker_receipt_image { nil }
    app { AppModel.make(:kpack, droplet_guid: guid) }
    state { VCAP::CloudController::DropletModel::STAGED_STATE }
    buildpack_lifecycle_data { nil.tap { |_| object.save } }
    kpack_lifecycle_data { KpackLifecycleDataModel.make(droplet: object.save) }
  end

  DeploymentModel.blueprint do
    state { VCAP::CloudController::DeploymentModel::DEPLOYING_STATE }
    status_value { VCAP::CloudController::DeploymentModel::ACTIVE_STATUS_VALUE }
    status_reason { VCAP::CloudController::DeploymentModel::DEPLOYING_STATUS_REASON }
    app { AppModel.make }
    droplet { DropletModel.make(app:) }
    deploying_web_process { ProcessModel.make(app: app, type: "web-deployment-#{Sham.guid}") }
    original_web_process_instance_count { 1 }
  end

  DeploymentProcessModel.blueprint do
    deployment { DeploymentModel.make }
    process_guid { Sham.guid }
    process_type { ProcessTypes::WEB }
  end

  TaskModel.blueprint do
    guid { Sham.guid }
    app { AppModel.make }
    name { Sham.name }
    droplet { DropletModel.make(app:) }
    command { 'bundle exec rake' }
    state { VCAP::CloudController::TaskModel::RUNNING_STATE }
    memory_in_mb { 256 }
    disk_in_mb {}
    sequence_id { Sham.sequence_id }
    failure_reason {}
  end

  TaskModel.blueprint(:running) do
    guid { Sham.guid }
    app { AppModel.make }
    name { Sham.name }
    droplet { DropletModel.make(app:) }
    command { 'bundle exec rake' }
    state { VCAP::CloudController::TaskModel::RUNNING_STATE }
    memory_in_mb { 256 }
    sequence_id { Sham.sequence_id }
  end

  TaskModel.blueprint(:canceling) do
    guid { Sham.guid }
    app { AppModel.make }
    name { Sham.name }
    droplet { DropletModel.make(app:) }
    command { 'bundle exec rake' }
    state { VCAP::CloudController::TaskModel::CANCELING_STATE }
    memory_in_mb { 256 }
    sequence_id { Sham.sequence_id }
  end

  TaskModel.blueprint(:succeeded) do
    guid { Sham.guid }
    app { AppModel.make }
    name { Sham.name }
    droplet { DropletModel.make(app:) }
    command { 'bundle exec rake' }
    state { VCAP::CloudController::TaskModel::SUCCEEDED_STATE }
    memory_in_mb { 256 }
    sequence_id { Sham.sequence_id }
  end

  TaskModel.blueprint(:pending) do
    guid { Sham.guid }
    app { AppModel.make }
    name { Sham.name }
    droplet { DropletModel.make(app:) }
    command { 'bundle exec rake' }
    state { VCAP::CloudController::TaskModel::PENDING_STATE }
    memory_in_mb { 256 }
    sequence_id { Sham.sequence_id }
  end

  PollableJobModel.blueprint do
    guid { Sham.guid }
    operation { 'app.job' }
    state { 'COMPLETE' }
    resource_guid { Sham.guid }
    resource_type { 'app' }
  end

  JobWarningModel.blueprint do
    guid { Sham.guid }
    detail { 'job warning' }
  end

  User.blueprint do
    guid { Sham.uaa_id }
  end

  Organization.blueprint do
    name              { Sham.name }
    quota_definition  { QuotaDefinition.make }
    status            { 'active' }
  end

  Domain.blueprint do
    name { Sham.domain }
  end

  PrivateDomain.blueprint do
    name                { Sham.domain }
    owning_organization { Organization.make }
  end

  SharedDomain.blueprint do
    name { Sham.domain }
  end

  SharedDomain.blueprint(:tcp) do
    router_group_guid { Sham.guid }
  end

  Route.blueprint do
    space { Space.make }
    domain { PrivateDomain.make(owning_organization: space.organization) }
    host { Sham.host }
  end

  Route.blueprint(:tcp) do
    port { Sham.port }
    domain { SharedDomain.make(:tcp) }
  end

  Space.blueprint do
    name              { Sham.name }
    organization      { Organization.make }
  end

  SpaceSupporter.blueprint do
    guid { Sham.guid }
    user { User.make }
    space { Space.make }
  end

  SpaceAuditor.blueprint do
    guid { Sham.guid }
    user { User.make }
    space { Space.make }
  end

  SpaceDeveloper.blueprint do
    guid { Sham.guid }
    user { User.make }
    space { Space.make }
  end

  SpaceManager.blueprint do
    guid { Sham.guid }
    user { User.make }
    space { Space.make }
  end

  OrganizationManager.blueprint do
    guid { Sham.guid }
    user { User.make }
    organization { Organization.make }
  end

  OrganizationBillingManager.blueprint do
    guid { Sham.guid }
    user { User.make }
    organization { Organization.make }
  end

  OrganizationUser.blueprint do
    guid { Sham.guid }
    user { User.make }
    organization { Organization.make }
  end

  OrganizationAuditor.blueprint do
    guid { Sham.guid }
    user { User.make }
    organization { Organization.make }
  end

  Service.blueprint do
    label                 { Sham.label }
    unique_id             { SecureRandom.uuid }
    bindable              { true }
    active                { true }
    service_broker        { ServiceBroker.make }
    description           { Sham.description } # remove hack
    extra                 { '{"shareable": true, "documentationUrl": "https://some.url.for.docs/"}' }
    instances_retrievable { false }
    bindings_retrievable  { false }
    plan_updateable       { false }
  end

  Service.blueprint(:routing) do
    requires { ['route_forwarding'] }
  end

  Service.blueprint(:volume_mount) do
    requires { ['volume_mount'] }
  end

  ServiceInstance.blueprint do
    name              { Sham.name }
    credentials       { Sham.service_credentials }
    space             { Space.make }
  end

  ManagedServiceInstance.blueprint do
    is_gateway_service         { true }
    name                       { Sham.name }
    credentials                { Sham.service_credentials }
    space                      { Space.make }
    service_plan               { ServicePlan.make }
    gateway_name               { Sham.guid }
    maintenance_info           {}
  end

  ManagedServiceInstance.blueprint(:all_fields) do
    gateway_data               { 'some data' }
    dashboard_url              { Sham.url }
    syslog_drain_url           { Sham.url }
    tags                       { %w[a-tag another-tag] }
    route_service_url          { Sham.url }
    maintenance_info           { 'maintenance info' }
  end

  ManagedServiceInstance.blueprint(:routing) do
    service_plan { ServicePlan.make(:routing) }
  end

  ManagedServiceInstance.blueprint(:volume_mount) do
    service_plan { ServicePlan.make(:volume_mount) }
  end

  UserProvidedServiceInstance.blueprint do
    name              { Sham.name }
    credentials       { Sham.service_credentials }
    syslog_drain_url  { Sham.url }
    space             { Space.make }
    is_gateway_service { false }
  end

  UserProvidedServiceInstance.blueprint(:routing) do
    name              { Sham.name }
    credentials       { Sham.service_credentials }
    route_service_url { Sham.url }
    syslog_drain_url  { Sham.url }
    space             { Space.make }
    is_gateway_service { false }
  end

  ServiceInstanceOperation.blueprint do
    type                      { 'create' }
    state                     { 'succeeded' }
    description               { 'description goes here' }
    updated_at                { Time.now.utc }
  end

  ServiceBindingOperation.blueprint do
    type                      { 'create' }
    state                     { 'succeeded' }
    description               { 'description goes here' }
    updated_at                { Time.now.utc }
  end

  ServiceKeyOperation.blueprint do
    type                      { 'create' }
    state                     { 'succeeded' }
    description               { 'description goes here' }
    updated_at                { Time.now.utc }
  end

  Stack.blueprint do
    name              { Sham.name }
    description       { Sham.description }
  end

  # if you want to create a process with droplet, use ProcessModelFactory.make
  # This is because the lack of factory hooks in Machinist.
  ProcessModel.blueprint do
    instances { 1 }
    type { 'web' }
    diego { true }
    app { AppModel.make }
    metadata { {} }
  end

  ProcessModel.blueprint(:process) do
    app { AppModel.make }
    diego { true }
    instances { 1 }
    type { Sham.name }
    metadata { {} }
  end

  ProcessModel.blueprint(:diego_runnable) do
    app { AppModel.make(droplet: DropletModel.make) }
    diego { true }
    instances { 1 }
    type { Sham.name }
    metadata { {} }
    state { 'STARTED' }
  end

  ProcessModel.blueprint(:docker) do
    app { AppModel.make(:docker) }
    diego { true }
    instances { 1 }
    type { Sham.name }
    metadata { {} }
  end

  ProcessModel.blueprint(:kpack) do
    app { AppModel.make(:kpack, droplet: DropletModel.make(:kpack)) }
    diego { true }
    instances { 1 }
    type { Sham.name }
    metadata { {} }
    state { 'STARTED' }
  end

  ProcessModel.blueprint(:nonmatching_guid) do
    instances { 1 }
    type { 'web' }
    diego { true }
    app { AppModel.make }
    metadata { {} }
    guid { Sham.guid }
  end

  RouteBinding.blueprint do
    service_instance { ManagedServiceInstance.make(:routing) }
    route { Route.make space: service_instance.space }
    route_service_url { Sham.url }
  end

  RouteBindingOperation.blueprint do
    type                      { 'create' }
    state                     { 'succeeded' }
    description               { 'description goes here' }
    updated_at                { Time.now.utc }
  end

  ServiceBinding.blueprint do
    credentials { Sham.service_credentials }
    service_instance { ManagedServiceInstance.make }
    app { AppModel.make(space: service_instance.space) }
    syslog_drain_url { nil }
    type { 'app' }
    name { nil }
    guid { Sham.guid }
  end

  ServiceKey.blueprint do
    credentials       { Sham.service_credentials }
    service_instance  { ManagedServiceInstance.make }
    name { Sham.name }
  end

  ServiceKey.blueprint(:credhub_reference) do
    credentials       { { 'credhub-ref' => Sham.name } }
    service_instance  { ManagedServiceInstance.make }
    name { Sham.name }
  end

  ServiceBroker.blueprint do
    name              { Sham.name }
    broker_url        { Sham.url }
    state             { ServiceBrokerStateEnum::AVAILABLE }
    auth_username     { Sham.auth_username }
    auth_password     { Sham.auth_password }
  end

  ServiceBroker.blueprint(:space_scoped) do
    space_id          { Space.make.id }
  end

  ServiceBrokerUpdateRequest.blueprint do
    name { Sham.name }
    broker_url { Sham.url }
    authentication { '{"credentials":{"username":"new-admin","password":"welcome"}}' }
    service_broker_id {}
    fk_service_brokers_id {}
  end

  ServiceDashboardClient.blueprint do
    uaa_id          { Sham.name }
    service_broker  { ServiceBroker.make }
  end

  ServicePlan.blueprint do
    name              { Sham.name }
    free              { false }
    description       { Sham.description }
    service           { Service.make }
    unique_id         { SecureRandom.uuid }
    active            { true }
    maintenance_info  {}
  end

  ServicePlan.blueprint(:routing) do
    service { Service.make(:routing) }
  end

  ServicePlan.blueprint(:volume_mount) do
    service { Service.make(:volume_mount) }
  end

  ServicePlanVisibility.blueprint do
    service_plan { ServicePlan.make(public: false) }
    organization { Organization.make }
  end

  Event.blueprint do
    guid { Sham.guid }
    timestamp  { Time.now.utc }
    type       { Sham.name }
    actor      { Sham.guid }
    actor_type { Sham.name }
    actor_name { Sham.name }
    actee      { Sham.guid }
    actee_type { Sham.name }
    actee_name { Sham.name }
    organization_guid { Sham.guid }
    metadata { {} }
  end

  AppEvent.blueprint do
    app               { ProcessModelFactory.make }
    instance_guid     { Sham.guid }
    instance_index    { Sham.instance_index }
    exit_status       { Random.rand(256) }
    exit_description  { Sham.description }
    timestamp         { Time.now.utc }
  end

  QuotaDefinition.blueprint do
    name { Sham.name }
    non_basic_services_allowed { true }
    total_reserved_route_ports { 5 }
    total_services { 60 }
    total_routes { 1_000 }
    memory_limit { 20_480 } # 20 GB
  end

  Buildpack.blueprint do
    name { Sham.name }
    stack { Stack.default.name }
    key { Sham.guid }
    position { Buildpack.count + 1 }
    enabled { true }
    filename { Sham.name }
    locked { false }
  end

  Buildpack.blueprint(:nil_stack) do
    stack { nil }
  end

  CustomBuildpack.blueprint do
    url { 'http://acme.com' }
  end

  BuildpackLifecycleDataModel.blueprint do
    buildpacks { nil }
    stack { Stack.make.name }
  end

  BuildpackLifecycleDataModel.blueprint(:all_fields) do
    buildpacks { ['http://example.com/repo.git'] }
    stack { Stack.make.name }
    app_guid { Sham.guid }
    droplet_guid { Sham.guid }
    admin_buildpack_name { 'admin-bp' }
    build { BuildModel.make }
  end

  CNBLifecycleDataModel.blueprint do
    buildpacks { nil }
    stack { Stack.make.name }
  end

  CNBLifecycleDataModel.blueprint(:all_fields) do
    buildpacks { ['docker://gcr.io/paketo-buildpacks/nodejs'] }
    stack { Stack.make.name }
    app_guid { Sham.guid }
    droplet_guid { Sham.guid }
    build { BuildModel.make }
  end

  KpackLifecycleDataModel.blueprint do
    build { BuildModel.make }
    buildpacks { [] }
  end

  BuildpackLifecycleBuildpackModel.blueprint do
    admin_buildpack_name { Buildpack.make(name: 'ruby').name }
    buildpack_url { nil }
  end

  BuildpackLifecycleBuildpackModel.blueprint(:all_fields) do
    buildpack_lifecycle_data_guid { BuildpackLifecycleDataModel.make.guid }
    cnb_lifecycle_data_guid { CNBLifecycleDataModel.make.guid }
    version { Sham.version }
    buildpack_name { Sham.name }
  end

  BuildpackLifecycleBuildpackModel.blueprint(:custom_buildpack) do
    admin_buildpack_name { nil }
    buildpack_url { 'http://example.com/temporary' }
  end

  AppUsageEvent.blueprint do
    state { 'STARTED' }
    package_state { 'STAGED' }
    instance_count { 1 }
    memory_in_mb_per_instance { 564 }
    app_guid { Sham.guid }
    app_name { Sham.name }
    org_guid { Sham.guid }
    space_guid { Sham.guid }
    space_name { Sham.name }
    buildpack_guid { Sham.guid }
    buildpack_name { Sham.name }
    process_type { 'web' }
  end

  ServiceUsageEvent.blueprint do
    state { 'CREATED' }
    org_guid { Sham.guid }
    space_guid { Sham.guid }
    space_name { Sham.name }
    service_instance_guid { Sham.guid }
    service_instance_name { Sham.name }
    service_instance_type { Sham.type }
    service_plan_guid { Sham.guid }
    service_plan_name { Sham.name }
    service_guid { Sham.guid }
    service_label { Sham.label }
  end

  SecurityGroup.blueprint do
    name { Sham.name }
    rules do
      [
        {
          'protocol' => 'udp',
          'ports' => '8080',
          'destination' => '198.41.191.47/1'
        }
      ]
    end
    running_default { false }
    staging_default { false }
  end

  SpaceQuotaDefinition.blueprint do
    name { Sham.name }
    non_basic_services_allowed { true }
    total_services { 60 }
    total_service_keys { 600 }
    total_routes { 1_000 }
    memory_limit { 20_480 } # 20 GB
    organization { Organization.make }
  end

  EnvironmentVariableGroup.blueprint do
    name { "runtime-#{Sham.instance_index}" }
    environment_json do
      {
        'MOTD' => 'Because of your smile, you make life more beautiful.',
        'COROPRATE_PROXY_SERVER' => 'abc:8080'
      }
    end
  end

  FeatureFlag.blueprint do
    name { 'user_org_creation' }
    enabled { false }
    error_message { Sham.error_message }
  end

  RouteMappingModel.blueprint do
    app { AppModel.make }
    route { Route.make(space: app.space) }
    process_type { 'web' }
    app_port { -1 }
    weight { nil }
  end

  SidecarModel.blueprint do
    name { Sham.name }
    command { 'bundle exec rackup' }
    app { AppModel.make }
    origin { SidecarModel::ORIGIN_USER }
  end

  SidecarProcessTypeModel.blueprint do
    type { 'web' }
    sidecar
    app_guid { sidecar.app_guid }
  end

  RevisionModel.blueprint do
    app { AppModel.make }
    droplet { DropletModel.make(app: object.app, process_types: { 'web' => 'default_revision_droplet_web_command' }) }
    description { 'Initial revision' }
    process_command_guids do
      break [] if object.droplet.process_types.blank?

      object.droplet.process_types.map do |type, _|
        RevisionProcessCommandModel.make(revision: object.save, process_type: type, process_command: nil).guid
      end
    end
  end

  RevisionModel.blueprint(:custom_web_command) do
    app { AppModel.make }
    droplet { DropletModel.make(app: object.app) }
    description { 'Initial revision' }
    process_command_guids do
      break [] if object.droplet.process_types.blank?

      object.droplet.process_types.map do |type, _|
        process_command = RevisionProcessCommandModel.make(revision: object.save, process_type: type, process_command: nil)
        process_command.update(process_command: 'custom_web_command') if type == 'web'
        process_command.guid
      end
    end
  end

  RevisionProcessCommandModel.blueprint do
    process_type { 'web' }
    process_command { '$HOME/boot.sh' }
  end

  RevisionSidecarModel.blueprint do
    name { 'sleepy' }
    command { 'sleep infinity' }
    revision { RevisionModel.make }
    revision_sidecar_process_type_guids { [RevisionSidecarProcessTypeModel.make(revision_sidecar: object.save).guid] }
  end

  RevisionSidecarProcessTypeModel.blueprint do
    type { 'web' }
  end

  OrphanedBlob.blueprint do
  end

  TestModel.blueprint do
    required_attr true
  end

  TestModelManyToOne.blueprint do
  end

  TestModelManyToMany.blueprint do
  end

  TestModelSecondLevel.blueprint do
  end

  TestModelRedact.blueprint do
  end
end
