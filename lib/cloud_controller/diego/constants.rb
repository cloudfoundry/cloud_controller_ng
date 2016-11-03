module VCAP::CloudController
  module Diego
    STAGING_DOMAIN                   = 'cf-app-staging'.freeze
    STAGING_TRUSTED_SYSTEM_CERT_PATH = '/etc/cf-system-certificates'.freeze
    STAGING_LOG_SOURCE               = 'STG'.freeze
    STAGING_LEGACY_DOWNLOAD_USER     = 'vcap'.freeze
    STAGING_DEFAULT_LANG             = 'en_US.UTF-8'.freeze
    STAGING_RESULT_FILE              = '/tmp/result.json'.freeze
    STAGING_TASK_CPU_WEIGHT          = 50
  end
end
