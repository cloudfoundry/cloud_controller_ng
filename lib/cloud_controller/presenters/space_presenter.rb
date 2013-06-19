require_relative 'abstract_presenter'

class SpacePresenter < AbstractPresenter
  def entity_hash
    {
      name: @object.name
    }
  end
end
