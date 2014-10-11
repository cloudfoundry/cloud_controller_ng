require_relative "job_presenter"

class StagingJobPresenter < JobPresenter
  def status_url
    config = VCAP::CloudController::Config.config
    local_route = config[:local_route]
    external_port = config[:external_port]
    user = config[:staging][:auth][:user]
    password = config[:staging][:auth][:password]

    "#{config[:external_protocol]}://#{user}:#{password}@#{local_route}:#{external_port}/staging/jobs/#{@object.guid}"
  end
end
