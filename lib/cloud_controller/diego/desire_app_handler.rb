module VCAP::CloudController
  module Diego
    class DesireAppHandler
      class << self
        def create_or_update_app(process_guid, recipe_builder, client)
          if (existing_lrp = client.get_app(process_guid))
            update_lrp = recipe_builder.build_app_lrp_update(existing_lrp)
            client.update_app(process_guid, update_lrp)
          else
            desired_lrp = recipe_builder.build_app_lrp
            client.desire_app(desired_lrp)
          end
        end
      end
    end
  end
end
