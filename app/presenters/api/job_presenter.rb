require_relative 'api_presenter'

class JobPresenter < ApiPresenter

  def initialize(object, url_host_name=nil)
    super(object)
    @object ||= NullJob.new
    @url_host_name = url_host_name
  end

  protected
  def metadata_hash
    {
      guid: @object.guid,
      created_at: @object.created_at.iso8601,
      url: [@url_host_name, "v2/jobs/#{@object.guid}"].join("/")
    }
  end

  def entity_hash
    entity_hash = {
      guid: @object.guid,
      status: status
    }
    if job_errored?
      entity_hash[:error] = error_deprecation_message
      entity_hash[:error_details] = ErrorPresenter.new(job_exception_or_nil).sanitized_hash
    end
    entity_hash
  end

  private

  def job_exception_or_nil
    if job_has_exception?
      VCAP::CloudController::ExceptionMarshaler.unmarshal(@object.cf_api_error)
    else
      nil
    end
  end

  def job_has_exception?
    @object.cf_api_error
  end

  def error_deprecation_message
    "Use of entity>error is deprecated in favor of entity>error_details."
  end

  def status
    if job_errored?
      "failed"
    elsif job_missing?
      "finished"
    elsif job_queued?
      "queued"
    else
      "running"
    end
  end

  def job_queued?
    @object.locked_at.nil?
  end

  def job_missing?
    @object.is_a? NullJob
  end

  def job_errored?
    @object.cf_api_error or @object.last_error
  end

  class NullJob
    def id
      "0"
    end

    def guid
      "0"
    end

    def created_at
      Time.at(0)
    end

    def run_at
      Time.at(0)
    end

    def cf_api_error
      nil
    end

    def last_error
      nil
    end
  end
end
