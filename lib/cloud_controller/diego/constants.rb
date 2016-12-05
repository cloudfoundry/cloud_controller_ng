module VCAP::CloudController
  module Diego
    STAGING_DOMAIN                   = 'cf-app-staging'.freeze
    STAGING_TRUSTED_SYSTEM_CERT_PATH = '/etc/cf-system-certificates'.freeze
    STAGING_LOG_SOURCE               = 'STG'.freeze
    STAGING_LEGACY_DOWNLOAD_USER     = 'vcap'.freeze
    STAGING_DEFAULT_LANG             = 'en_US.UTF-8'.freeze
    STAGING_RESULT_FILE              = '/tmp/result.json'.freeze
    STAGING_TASK_CPU_WEIGHT          = 50

    RUNNING_TRUSTED_SYSTEM_CERT_PATH = '/etc/cf-system-certificates'.freeze
    DEFAULT_APP_PORT = 8080
    LRP_LOG_SOURCE = 'CELL'.freeze
    APP_LOG_SOURCE = 'APP'.freeze
    HEALTH_LOG_SOURCE = 'HEALTH'.freeze
    DEFAULT_FILE_DESCRIPTOR_LIMIT = 1024
    DEFAULT_LANG = 'en_US.UTF-8'.freeze

    APP_LRP_DOMAIN = 'cf-apps'.freeze
  end
end
