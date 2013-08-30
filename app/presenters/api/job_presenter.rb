require_relative 'api_presenter'

class JobPresenter < ApiPresenter

  def initialize(object)
    super
    @object ||= NullJob.new
  end

  protected

  def metadata_hash
    {
      guid: @object.guid,
      created_at: @object.created_at.iso8601,
      url: "/v2/jobs/#{@object.guid}"
    }
  end

  def entity_hash
    {
      guid: @object.guid,
      status: status
    }
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