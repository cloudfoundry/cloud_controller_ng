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

    def initialize(user, logger, request)
      @user    = user
      @logger  = logger
      @opts    = parse_params(request.params)
    end

    def parse_params(params)
      { :q => params["q"] }
    end

    def dispatch(method, *args)
      send(method, *args)
    rescue Sequel::ValidationFailed => e
      raise self.class.translate_and_log_exception(@logger, e)
    rescue Sequel::DatabaseError => e
      raise self.class.translate_and_log_exception(@logger, e)
    end

    def create(json)
      validate_class_access(:create)
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
      obj = find_id_and_validate_access(:read, id)
      ObjectSerialization.render_json(self.class, obj)
    end

    def update(id, json)
      obj = find_id_and_validate_access(:update, id)
      attributes = Yajl::Parser.new.parse(json)
      obj.update_from_hash(attributes)
      obj.save
      [HTTP::CREATED, ObjectSerialization.render_json(self.class, obj)]
    rescue Sequel::ValidationFailed => e
      raise self.class.translate_validation_exception(e, attributes)
    end

    def delete(id)
      obj = find_id_and_validate_access(:delete, id)
      obj.delete
      [HTTP::NO_CONTENT, nil]
    rescue Sequel::ValidationFailed => e
      raise self.class.translate_validation_exception(e, attributes)
    end

    def enumerate
      # TODO: filter the ds by what the user can see
      ds = Query.dataset_from_query_params(model, self.class.query_parameters, @opts)
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

    def validate_class_access(op)
      validate_access(op, model, @user)
    end

    def find_id_and_validate_access(op, id)
      obj = model.find(:id => id)
      if obj
        validate_access(op, obj, @user)
      else
        raise self.class.not_found_exception.new(id) if obj.nil?
      end
      obj
    end

    def validate_access(op, obj, user)
      user_perms = VCAP::CloudController::Permissions.permissions_for(obj, user)
      unless self.class.op_allowed_by?(op, user_perms)
        raise NotAuthenticated unless user
        raise NotAuthorized
      end
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
          @query_parameters ||= Set.new
        else
          @query_parameters ||= Set.new
          @query_parameters |= Set.new(args.map { |a| a.to_s })
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
        VCAP::CloudController::Errors::InvalidRequest
      end
    end
  end
end
