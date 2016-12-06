module VCAP::CloudController
  module Diego
    class DesireAppHandler
      class << self
        def create_app(recipe_builder, client)
          desired_lrp = recipe_builder.build_app_lrp
          client.desire_app(desired_lrp)
        end
      end
    end
  end
end
