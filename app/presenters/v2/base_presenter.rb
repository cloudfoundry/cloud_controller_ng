module CloudController
  module Presenters
    module V2
      class BasePresenter
        def to_hash(controller, obj, opts, depth, parents, orphans=nil)
          {
            'metadata' => metadata_hash(obj, controller),
            'entity'   => entity_hash(controller, obj, opts, depth, parents, orphans)
          }
        end

        def entity_hash(*_args)
          raise NotImplementedError.new
        end

        private

        def metadata_hash(obj, controller)
          metadata_hash = {
            'guid'       => obj.guid,
            'url'        => controller.url_for_guid(obj.guid),
            'created_at' => obj.created_at,
          }
          metadata_hash['updated_at'] = obj.updated_at if obj.respond_to?(:updated_at)
          metadata_hash
        end
      end
    end
  end
end
