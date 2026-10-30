require_relative 'job_presenter'

class StagingJobPresenter < JobPresenter
  def status_url
    config = VCAP::CloudController::Config.config

    URI::HTTPS.build(
      host: config.get(:internal_service_hostname),
      port: config.get(:tls_port),
      path: "/internal/v4/staging_jobs/#{@object.guid}"
    ).to_s
  end
end
