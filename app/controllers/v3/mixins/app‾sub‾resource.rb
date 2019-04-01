require 'controllers/v3/mixins/sub_resource'

module AppSubResource
  include SubResource

  private

  def app_not_found!
    resource_not_found!(:app)
  end
end
