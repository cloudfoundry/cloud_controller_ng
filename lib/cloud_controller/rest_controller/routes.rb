# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::RestController

  # Define routes for the rest endpoint.
  module Routes
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def define_route(verb, path, method = nil, &blk)
        opts = {}
        opts[:consumes] = [:json] if [:put, :post].include?(verb)
        klass = self
        controller.send(verb, path, opts) do |*args|
          logger.debug "dispatch #{klass} #{verb} #{path}"
          api = klass.new(@config, logger, env, request.params, request.body, self)
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
          [:get,    path_id, :read],
          [:put,    path_id, :update],
          [:delete, path_id, :delete]
        ].each do |verb, path, method|
          define_route(verb, path, method)
        end
      end

      def define_to_many_routes
        to_many_relationships.each do |name, attr|
          get "#{path_id}/#{name}" do |api, id|
            api.dispatch(:enumerate_related, id, name)
          end

          put "#{path_id}/#{name}/:other_id" do |api, id, other_id|
            api.dispatch(:add_related, id, name, other_id)
          end

          delete "#{path_id}/#{name}/:other_id", do |api, id, other_id|
            api.dispatch(:remove_related, id, name, other_id)
          end
        end
      end

      def controller
        VCAP::CloudController::Controller
      end
    end
  end
end
