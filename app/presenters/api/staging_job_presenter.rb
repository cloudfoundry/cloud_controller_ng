require_relative 'job_presenter'

class StagingJobPresenter < JobPresenter
  def status_url
    config = VCAP::CloudController::Config.config

    if HashUtils.dig(config, :diego, :temporary_cc_uploader_mtls)
      URI::HTTPS.build(
        host:     config[:internal_service_hostname],
        port:     config[:tls_port],
        path:     "/internal/v4/staging_jobs/#{@object.guid}",
      ).to_s
    else
      uri = URI::HTTP.build(
        host:     config[:internal_service_hostname],
        port:     config[:external_port],
        path:     "/staging/jobs/#{@object.guid}",
      )
      uri.userinfo = [config[:staging][:auth][:user], config[:staging][:auth][:password]]
      uri.to_s
    end
  end
end
