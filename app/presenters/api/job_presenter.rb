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
    entity_hash[:error] = @object.last_error if @object.last_error.present?
    entity_hash
  end

  private

  def status
    if @object.last_error
      "failed"
    elsif @object.is_a? NullJob
      "finished"
    elsif @object.locked_at.nil?
      "queued"
    else
      "running"
    end
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

    def last_error
      nil
    end
  end
end
