require_relative 'abstract_presenter'

class UserPresenter < AbstractPresenter
  def entity_hash
    {
        admin: @object.admin?,
        active: @object.active?,
        default_space_guid: @object.default_space_guid
    }
  end
end
