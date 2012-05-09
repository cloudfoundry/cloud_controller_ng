# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::RestController
  module Routes
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def define_routes
        define_create_route
        define_read_route
        define_update_route
        define_delete_route
        define_enumerate_route
      end

      def define_create_route
        klass = self
        controller.post path, :consumes => [:json] do
          klass.new(@user, logger).dispatch(:create, request.body)
        end
      end

      def define_read_route
        klass = self
        controller.get path_id do |id|
          klass.new(@user, logger).dispatch(:read, id)
        end
      end

      def define_update_route
        klass = self
        controller.put path_id, :consumes => [:json] do |id|
          klass.new(@user, logger).dispatch(:update, id, request.body)
        end
      end

      def define_delete_route
        klass = self
        controller.delete path_id do |id|
          klass.new(@user, logger).dispatch(:delete, id)
        end
      end

      def define_enumerate_route
        klass = self
        controller.get path, do
          # FIXME: replace with URI parse on the query string.
          # Sinatra squshes duplicate quary parms into a single entry rather
          # than an array
          klass.new(@user, logger).dispatch(:enumerate, request.params["q"])
        end
      end

      def controller
        VCAP::CloudController::Controller
      end
    end
  end
end
