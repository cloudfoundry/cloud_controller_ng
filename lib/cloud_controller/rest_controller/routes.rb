module VCAP::CloudController::RestController
  module Routes
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def define_route(verb, path, method = nil, &blk)
        opts = {}
        klass = self
        controller.send(verb, path, opts) do |*args|
          logger.debug "dispatch #{klass} #{verb} #{path}"
          controller_factory = CloudController::ControllerFactory.new(@config, logger, env, request.params, request.body, self)
          api = controller_factory.create_controller(klass)
          if method
            api.dispatch(method, *args)
          else
            blk.yield(api, *args)
          end
        end
      end

      [:post, :get, :put, :delete].each do |verb|
        define_method(verb) do |*args, &blk|
          (path, method) = *args
          define_route(verb, path, method, &blk)
        end
      end

      def define_routes
        define_standard_routes
        define_to_many_routes
      end

      private

      def define_standard_routes
        [
          [:post,   path,    :create],
          [:get,    path,    :enumerate],
          [:get,    path_guid, :read],
          [:put,    path_guid, :update],
          [:delete, path_guid, :delete]
        ].each do |verb, path, method|
          define_route(verb, path, method)
        end
      end

      def define_to_many_routes
        to_many_relationships.each do |name, attr|
          get "#{path_guid}/#{name}" do |api, id|
            api.dispatch(:enumerate_related, id, name)
          end

          put "#{path_guid}/#{name}/:other_id" do |api, id, other_id|
            api.dispatch(:add_related, id, name, other_id)
          end

          delete "#{path_guid}/#{name}/:other_id" do |api, id, other_id|
            api.dispatch(:remove_related, id, name, other_id)
          end
        end
      end

      def controller
        VCAP::CloudController::FrontController
      end
    end
  end
end
