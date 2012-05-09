# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::RestController
  class Base
    include VCAP::CloudController::Errors
    include VCAP::RestAPI
    include PermissionManager
    include Messages
    include Routes

    define_permitted_operation :create
    define_permitted_operation :read
    define_permitted_operation :update
    define_permitted_operation :delete
    define_permitted_operation :enumerate

    def initialize(user, logger)
      @user   = user
      @logger = logger
    end

    def dispatch(method, *args)
      validate_access method, @user
      send(method, *args)
    rescue Sequel::ValidationFailed => e
      raise self.class.translate_and_log_exception(@logger, e)
    rescue Sequel::DatabaseError => e
      raise self.class.translate_and_log_exception(@logger, e)
    end

    def validate_access(op, user)
      user_perms = VCAP::CloudController::Permissions.permissions_for(user)
      unless self.class.op_allowed_by?(op, user_perms)
        raise NotAuthenticated unless user
        raise NotAuthorized
      end
    end

    def create(json)
      attributes = Yajl::Parser.new.parse(json)
      raise InvalidRequest unless attributes
      obj = model.create_from_hash(attributes)
      [HTTP::CREATED,
       { "Location" => "#{self.class.path}/#{obj.id}" },
      ObjectSerialization.render_json(self.class, obj)]
    rescue Sequel::ValidationFailed => e
      raise self.class.translate_validation_exception(e, attributes)
    end

    def read(id)
      obj = find_id(id)
      ObjectSerialization.render_json(self.class, obj)
    end

    def update(id, json)
      obj = find_id(id)
      attributes = Yajl::Parser.new.parse(json)
      obj.update_from_hash(attributes)
      obj.save
      [HTTP::CREATED, ObjectSerialization.render_json(self.class, obj)]
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

    def enumerate(query_params)
      # TODO: filter the ds by what the user can see
      ds = QueryStringParser.data_set_from_query_params(model, query_params)
      resources = []
      ds.all.each do |m|
        resources << ObjectSerialization.to_hash(self.class, m)
      end

      res = {}
      res[:total_results] = ds.count
      res[:prev_url] = nil
      res[:next_url] = nil
      res[:resources] = resources

      Yajl::Encoder.encode(res, :pretty => true)
    end

    def find_id(id)
      obj = model.find(:id => id)
      raise self.class.not_found_exception.new(id) if obj.nil?
      obj
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

      def url_for_id(id)
        "#{path}/#{id}"
      end

      def model(name = model_class_name)
        VCAP::CloudController::Models.const_get(name)
      end

      def model_class_name
        class_basename
      end

      def not_found_exception_name
        "#{model_class_name}NotFound"
      end

      def not_found_exception
        VCAP::CloudController::Errors.const_get(not_found_exception_name)
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
          include ControllerDSL
        end

        k.new(self).instance_eval(&blk)
      end

      def translate_and_log_exception(logger, e)
        msg = ["exception not translated: #{e.class} - #{e.message}"]
        msg[0] = msg[0] + ":"
        msg.concat(e.backtrace).join("\\n")
        logger.warn(msg.join("\\n"))
        VCAP::CloudController::InvalidRequest.new
      end
    end
  end
end
