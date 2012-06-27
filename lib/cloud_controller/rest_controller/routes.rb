# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::RestController

  # Define routes for the rest endpoint.
  module Routes
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods

      # Define routes for the rest endpoint.
      def define_routes
        define_create_route
        define_read_route
        define_update_route
        define_delete_route
        define_enumerate_route

        define_to_many_routes
      end

      private

      def define_create_route
        klass = self
        controller.post path, :consumes => [:json] do
          api = klass.new(logger, request.body, request.params)
          api.dispatch(:create)
        end
      end

      def define_read_route
        klass = self
        controller.get path_id do |id|
          api = klass.new(logger, request.body, request.params)
          api.dispatch(:read, id)
        end
      end

      def define_update_route
        klass = self
        controller.put path_id, :consumes => [:json] do |id|
          api = klass.new(logger, request.body, request.params)
          api.dispatch(:update, id)
        end
      end

      def define_delete_route
        klass = self
        controller.delete path_id do |id|
          api = klass.new(logger, request.body, request.params)
          api.dispatch(:delete, id)
        end
      end

      def define_enumerate_route
        klass = self
        controller.get path, do
          api = klass.new(logger, request.body, request.params)
          api.dispatch(:enumerate)
        end
      end

      def define_to_many_routes
        klass = self
        to_many_relationships.each do |name, attr|
          controller.get "#{path_id}/#{name}" do |id|
            api = klass.new(logger, request.body, request.params)
            api.dispatch(:enumerate_related, id, name)
          end

          controller.put "#{path_id}/#{name}/:other_id" do |id, other_id|
            api = klass.new(logger, request.body, request.params)
            api.dispatch(:add_related, id, name, other_id)
          end

          controller.delete "#{path_id}/#{name}/:other_id" do |id, other_id|
            api = klass.new(logger, request.body, request.params)
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
