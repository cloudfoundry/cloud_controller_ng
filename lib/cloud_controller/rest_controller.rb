# Copyright (c) 2009-2012 VMware Inc.

module VCAP::CloudController
  module RestController
    class Base
      extend AccessController
      extend RestController
      extend VCAP::RestAPI
      include VCAP::RestAPI

      define_access_type :create
      define_access_type :read
      define_access_type :update
      define_access_type :delete
      define_access_type :enumerate

      def create(json)
        attributes = Yajl::Parser.new.parse(json)
        raise InvalidRequest unless attributes
        obj = model.create_from_hash(attributes)
        [HTTP::CREATED, { "Location" => "#{self.class.path}/#{obj.id}" }, obj.to_json]
      rescue Sequel::ValidationFailed => e
        raise self.class.translate_validation_exception(e, attributes)
      end

      def read(id, attr = nil)
        obj = find_id(id)
        only_export = [attr] if attr
        obj.to_json(:only => only_export)
      end

      def update(id, json)
        obj = find_id(id)
        attributes = Yajl::Parser.new.parse(json)
        obj.update_from_hash(attributes)
        obj.save
        [HTTP::CREATED, obj.to_json]
      rescue Sequel::ValidationFailed => e
        raise self.class.translate_validation_exception(e, attributes)
      end

      def delete(id)
        obj = find_id(id)
        obj.delete
        [HTTP::NO_CONTENT, nil]
      rescue Sequel::ValidationFailed => e
        raise self.class.translate_validation_exception(e, attributes)
      end

      def enumerate
        model.to_json
      end

      def find_id(id)
        obj = model.find(:id => id)
        raise self.class.not_found_exception.new(id) if obj.nil?
        obj
      end

      def dispatch(user, method, *args)
        validate_access method, user
        send(method, *args)
      rescue Sequel::ValidationFailed => e
        raise translate_and_log_exception(logger, e)
      rescue Sequel::DatabaseError => e
        raise translate_and_log_exception(logger, e)
      end

      def validate_access(op, user)
        unless self.class.roles_have_access?(op, user_roles(user))
          raise NotAuthenticated unless user
          raise NotAuthorized
        end
      end

      def user_roles(user)
        roles = []
        if user
          if user.admin?
            roles << Role::CFAdmin
          end
        end
        roles
      end

      def translate_and_log_exception(logger, e)
        msg = ["exception not translated: #{e.class} - #{e.message}"]
        msg[0] = msg[0] + ":"
        msg.concat(e.backtrace).join("\\n")
        logger.warn(msg.join("\\n"))
        VCAP::CloudController::InvalidRequest.new
      end

      def model
        self.class.model
      end

      class << self
        attr_accessor :attributes
        attr_accessor :to_many_relationships
        attr_accessor :to_one_relationships

        def class_basename
          self.name.split("::").last
        end

        def path
          "/v2/#{class_basename.underscore.pluralize}"
        end

        def path_id
          "#{path}/:id"
        end

        def model
          VCAP::CloudController::Models.const_get(model_class_name)
        end

        def model_class_name
          class_basename
        end

        def not_found_exception_name
          "#{model_class_name}NotFound"
        end

        def not_found_exception
          VCAP::CloudController.const_get(not_found_exception_name)
        end

        def query_parameters(*args)
          if args.empty?
            @query_parameters
          else
            @query_parameters = []
            @query_parameters |= args
          end
        end

        def define_attributes(&blk)
          k = Class.new do
            include DSL
          end

          k.new(self).instance_eval(&blk)
        end

        private

        def define_messages
          define_message(:response)
          define_message(:create)
          define_message(:update)
        end

        def define_message(type)
          attrs   = attributes
          to_one  = to_one_relationships  || {}
          to_many = to_many_relationships || {}

          klass = Class.new VCAP::RestAPI::Message do
            attrs.each do |name, attr|
              unless attr.exclude_in?(type)
                if (type == :update || (type == :create && attr.default))
                  optional name, attr.schema
                else
                  required name, attr.schema
                end
              end
            end

            to_one.each do |name, relation|
              unless relation.exclude_in?(type)
                if (type == :update || (type == :create &&
                                        relation.optional_in?(type)))
                  optional "#{name}_id", Integer
                else
                  required "#{name}_id", Integer
                end

                optional "#{name}_url", Message::HTTPS_URL if type == :response
              end
            end

             to_many.each do |name, relation|
              unless relation.exclude_in?(type)
                if type == :response
                  optional "#{name}_url", Message::HTTPS_URL
                else
                  optional "#{name}_id", [Integer]
                end
              end
            end
          end

          self.const_set "#{type.to_s.camelize}Message", klass
        end

        def define_routes
          define_create_route
          define_read_route
          define_update_route
          define_delete_route
          define_enumerate_route
        end

        def define_create_route
          klass = self
          Controller.post path, :consumes => [:json] do
            klass.new.dispatch(@user, :create, request.body)
          end
        end

        def define_read_route
          klass = self
          Controller.get path_id do |id|
            klass.new.dispatch(@user, :read, id.to_i)
          end
        end

        def define_update_route
          klass = self
          Controller.put path_id, :consumes => [:json] do |id|
            klass.new.dispatch(@user, :update, id.to_i, request.body)
          end
        end

        def define_delete_route
          klass = self
          Controller.delete path_id do |id|
            klass.new.dispatch(@user, :delete, id.to_i)
          end
        end

        def define_enumerate_route
          klass = self
          Controller.get path, do
            klass.new.dispatch(@user, :enumerate)
          end
        end
      end
    end

    module DSL
      include VCAP::RestAPI

      def initialize(controller)
        @controller = controller
      end

      def attribute(name, schema, opts = {})
        attributes[name] = SchemaAttribute.new(name, schema, opts)
      end

      def from_model(name, schema, opts = {})
        attributes[name] = SchemaAttribute.new(name, schema, opts)
      end

      def to_many(name, opts = {})
        to_many_relationships[name] = ToManyAttribute.new(name, opts)
      end

      def to_one(name, opts = {})
        to_one_relationships[name] = ToOneAttribute.new(name, opts)
      end

      private

      def attributes
        @controller.attributes ||= {}
      end

      def to_many_relationships
        @controller.to_many_relationships ||= {}
      end

      def to_one_relationships
        @controller.to_one_relationships ||= {}
      end
    end

  end

  def self.rest_controller(name, &blk)
    klass = Class.new RestController::Base
    self.const_set name, klass
    klass.class_eval &blk
    klass.class_eval do
      define_messages
      define_routes
    end
  end
end
