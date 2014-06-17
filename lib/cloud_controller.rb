require "bcrypt"
require "sinatra"
require "sequel"
require "thin"
require "yajl"
require "delayed_job"
require "newrelic_rpm"

require "allowy"

require "eventmachine/schedule_sync"

require "vcap/common"
require "cf-registrar"
require "vcap/errors/details"
require "vcap/errors/api_error"
require "uaa/token_coder"

require "sinatra/vcap"
require "cloud_controller/security_context"
require "active_support/core_ext/hash"
require "active_support/core_ext/object/to_query"
require "active_support/json/encoding"

module VCAP::CloudController; end

require "vcap/errors/invalid_relation"
require "vcap/errors/missing_required_scope_error"
require "sequel_plugins/sequel_plugins"
require "vcap/sequel_add_association_dependencies_monkeypatch"
require "access/access"


require "cloud_controller/jobs"
require "cloud_controller/background_job_environment"
require "cloud_controller/db_migrator"
require "cloud_controller/diagnostics"
require "cloud_controller/steno_configurer"
require "cloud_controller/constants"

require "controllers/base/front_controller"

require "cloud_controller/config"
require "cloud_controller/db"
require "cloud_controller/runner"
require "cloud_controller/app_observer"
require "cloud_controller/app_stager_task"
require "cloud_controller/controllers"
require "cloud_controller/roles"
require "cloud_controller/encryptor"
require "cloud_controller/blobstore/client"
require "cloud_controller/blobstore/url_generator"
require "cloud_controller/dependency_locator"
require "cloud_controller/controller_factory"
require "cloud_controller/start_app_message"
require "cloud_controller/egress_network_rules_presenter"

require "cloud_controller/legacy_api/legacy_api_base"
require "cloud_controller/legacy_api/legacy_info"
require "cloud_controller/legacy_api/legacy_services"
require "cloud_controller/legacy_api/legacy_service_gateway"
require "cloud_controller/legacy_api/legacy_bulk"

require "cloud_controller/resource_pool"

require "cloud_controller/dea/dea_pool"
require "cloud_controller/dea/dea_client"
require "cloud_controller/dea/dea_respondent"

require "cloud_controller/diego/diego_client"
require "cloud_controller/diego/buildpack_entry_generator"
require "cloud_controller/diego/service_registry"

require "cloud_controller/stager/stager_pool"
require "cloud_controller/stager/staging_completion_handler"

require "cloud_controller/hm9000_client"
require "cloud_controller/hm9000_respondent"

require "cloud_controller/task_client"

require "cloud_controller/structured_error"
require "cloud_controller/http_request_error"
require "cloud_controller/http_response_error"

require "cloud_controller/install_buildpacks"
require "cloud_controller/upload_buildpack"

require "cloud_controller/instances_reporter/legacy_instances_reporter"
require "cloud_controller/instances_reporter/diego_instances_reporter"
require "cloud_controller/instances_reporter/instances_reporter_factory"

require "services"
