require 'sinatra'
require 'sequel'
require 'thin'
require 'multi_json'
require 'delayed_job'

require 'allowy'

require 'vcap/common'
require 'uaa/token_coder'

require 'sinatra/vcap'
require File.expand_path('../../config/environment', __FILE__)

Sequel.default_timezone = :utc
ActiveSupport::JSON::Encoding.time_precision = 0

module VCAP::CloudController; end

require 'cloud_controller/errors/api_error'
require 'cloud_controller/errors/not_authenticated'
require 'cloud_controller/errors/not_found'
require 'cloud_controller/errors/blob_not_found'
require 'cloud_controller/errors/details'
require 'cloud_controller/errors/invalid_auth_token'
require 'cloud_controller/errors/invalid_relation'
require 'cloud_controller/errors/invalid_app_relation'
require 'cloud_controller/errors/invalid_route_relation'
require 'cloud_controller/errors/no_running_instances'
require 'delayed_job_plugins/deserialization_retry'
require 'delayed_job_plugins/after_enqueue_hook'
require 'sequel_plugins/sequel_plugins'
require 'vcap/sequel_add_association_dependencies_monkeypatch'
require 'access/access'

require 'cloud_controller/security_context'
require 'cloud_controller/jobs'
require 'cloud_controller/background_job_environment'
require 'cloud_controller/db_migrator'
require 'cloud_controller/diagnostics'
require 'cloud_controller/steno_configurer'
require 'cloud_controller/constants'

require 'controllers/base/front_controller'

require 'cloud_controller/config'
require 'cloud_controller/db'
require 'cloud_controller/runner'
require 'cloud_controller/app_observer'
require 'cloud_controller/collection_transformers'
require 'cloud_controller/controllers'
require 'cloud_controller/roles'
require 'cloud_controller/encryptor'
require 'cloud_controller/membership'
require 'cloud_controller/permissions'
require 'cloud_controller/serializer'
require 'cloud_controller/blobstore/client'
require 'cloud_controller/blobstore/url_generator'
require 'cloud_controller/blobstore/blob_key_generator'
require 'cloud_controller/dependency_locator'
require 'cloud_controller/file_path_checker'
require 'cloud_controller/rule_validator'
require 'cloud_controller/transport_rule_validator'
require 'cloud_controller/icmp_rule_validator'
require 'cloud_controller/controller_factory'
require 'cloud_controller/egress_network_rules_presenter'
require 'cloud_controller/admin_buildpacks_presenter'
require 'cloud_controller/organization_instance_usage_calculator'
require 'cloud_controller/url_secret_obfuscator'

require 'cloud_controller/legacy_api/legacy_api_base'
require 'cloud_controller/legacy_api/legacy_info'

require 'cloud_controller/resource_pool'

require 'cloud_controller/diego/nsync_client'
require 'cloud_controller/diego/stager_client'
require 'cloud_controller/diego/tps_client'

require 'cloud_controller/structured_error'
require 'cloud_controller/http_request_error'
require 'cloud_controller/http_response_error'

require 'cloud_controller/install_buildpacks'
require 'cloud_controller/upload_buildpack'

require 'cloud_controller/errors/instances_unavailable'

require 'cloud_controller/uaa/errors'
require 'cloud_controller/uaa/uaa_client'

require 'cloud_controller/bits_expiration'

require 'cloud_controller/routing_api/routing_api_client'
require 'cloud_controller/routing_api/disabled_routing_api_client'
require 'cloud_controller/routing_api/router_group'

require 'cloud_controller/route_validator'

require 'cloud_controller/integer_array_serializer'
require 'cloud_controller/port_generator'

require 'cloud_controller/route_binding_message'
require 'cloud_controller/process_route_handler'

require 'cloud_controller/isolation_segment_selector'
require 'cloud_controller/user_audit_info'

require 'services'
