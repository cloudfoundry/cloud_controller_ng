require_relative 'api_presenter'

class UserPresenter < ApiPresenter
  def entity_hash
    {
        admin: @object.admin,
        active: @object.active?,
        default_space_guid: @object.default_space_guid
    }
  end
end
