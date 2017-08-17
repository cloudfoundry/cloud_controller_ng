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
    DEFAULT_FILE_DESCRIPTOR_LIMIT    = 1024
    DEFAULT_LANG                     = 'en_US.UTF-8'.freeze
    DEFAULT_APP_PORT                 = 8080
    DEFAULT_SSH_PORT                 = 2222
    LRP_LOG_SOURCE                   = 'CELL'.freeze
    TASK_LOG_SOURCE                  = 'CELL'.freeze
    APP_LOG_SOURCE                   = 'APP'.freeze
    HEALTH_LOG_SOURCE                = 'HEALTH'.freeze
    SSHD_LOG_SOURCE                  = "#{LRP_LOG_SOURCE}/SSHD".freeze

    APP_LRP_DOMAIN     = 'cf-apps'.freeze
    APP_LRP_DOMAIN_TTL = 2.minutes

    TASKS_DOMAIN     = 'cf-tasks'.freeze
    TASKS_DOMAIN_TTL = 2.minutes

    CF_ROUTES_KEY  = 'cf-router'.freeze
    TCP_ROUTES_KEY = 'tcp-router'.freeze
    SSH_ROUTES_KEY = 'diego-ssh'.freeze

    BULKER_TASK_FAILURE = 'Unable to determine completion status'.freeze

    LRP_STARTING = 'STARTING'.freeze
    LRP_RUNNING  = 'RUNNING'.freeze
    LRP_CRASHED  = 'CRASHED'.freeze
    LRP_DOWN     = 'DOWN'.freeze
    LRP_UNKNOWN  = 'UNKNOWN'.freeze
  end
end
