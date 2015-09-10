require_relative 'job_presenter'

class StagingJobPresenter < JobPresenter
  def status_url
    config = VCAP::CloudController::Config.config
    external_domain = config[:external_domain]
    user = config[:staging][:auth][:user]
    password = config[:staging][:auth][:password]

    "#{config[:external_protocol]}://#{user}:#{password}@#{external_domain}/staging/jobs/#{@object.guid}"
  end
end
