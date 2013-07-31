require_relative 'api_presenter'

class SpacePresenter < ApiPresenter
  def entity_hash
    {
      name: @object.name
    }
  end
end
