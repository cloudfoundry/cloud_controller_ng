require_relative 'api_presenter'

class JobPresenter < ApiPresenter

  protected

  def metadata_hash
    {
      guid: @object.id,
      created_at: @object.created_at.iso8601,
      url: "/v2/jobs/#{@object.id}"
    }
  end

  def entity_hash
    {
      guid: @object.id,
      status: "queued"
    }
  end
end