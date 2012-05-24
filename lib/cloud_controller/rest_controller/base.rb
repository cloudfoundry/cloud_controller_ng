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
      # FIXME: replace with URI parse on the query string.
      # Sinatra squshes duplicate query parms into a single entry rather
      # than an array (which we might have for q)
      res = {}
      [ [ "inline-relations-depth", Integer ],
        [ "page",                   Integer ],
        [ "results-per-page",       Integer ],
        [ "q",                      String  ]
      ].each do |key, klass|
        val = params[key]
        res[key.underscore.to_sym] = Object.send(klass.name, val) if val
      end
      res
    end

    def dispatch(op, *args)
      send(op, *args)
    rescue Sequel::ValidationFailed => e
      raise self.class.translate_and_log_exception(@logger, e)
    rescue Sequel::DatabaseError => e
      raise self.class.translate_and_log_exception(@logger, e)
    end

    def with_quota_enforcement(quota_request_body, &blk)
      token = QuotaManager.fetch_quota_token(quota_request_body)
      ret = nil
      begin
        ret = blk.call
      rescue Sequel::ValidationFailed => e
        raise self.class.translate_validation_exception(e, request_attrs)
      end
      token.commit
      return ret
    rescue QuotaDeclined => e
      raise e
    rescue Exception => e
      token.abandon(e.message) unless token.nil?
      raise e
    end

    def create_quota_token_request
    end

    def create(json)
      validate_class_access(:create)
      @request_attrs = Yajl::Parser.new.parse(json)
      raise InvalidRequest unless request_attrs

      with_quota_enforcement(create_quota_token_request) do
        obj = model.create_from_hash(request_attrs)
        [HTTP::CREATED,
         { "Location" => "#{self.class.path}/#{obj.id}" },
        ObjectSerialization.render_json(self.class, obj, @opts)]
      end
    end

    def read(id)
      obj = find_id_and_validate_access(:read, id)
      ObjectSerialization.render_json(self.class, obj, @opts)
    end

    def update(id, json)
      obj = find_id_and_validate_access(:update, id)
      request_attrs = Yajl::Parser.new.parse(json)
      obj.update_from_hash(request_attrs)
      obj.save
      [HTTP::CREATED, ObjectSerialization.render_json(self.class, obj, @opts)]
    rescue Sequel::ValidationFailed => e
      raise self.class.translate_validation_exception(e, request_attrs)
    end

    def delete(id)
      obj = find_id_and_validate_access(:delete, id)
      obj.destroy
      [HTTP::NO_CONTENT, nil]
    rescue Sequel::ValidationFailed => e
      raise self.class.translate_validation_exception(e, request_attrs)
    end

    def enumerate
      raise NotAuthenticated unless @user
      authz_filter = admin_enumeration_filter
      ds = Query.dataset_from_query_params(model, authz_filter, self.class.query_parameters, @opts)
      Paginator.render_json(self.class, ds, @opts)
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

    def admin_enumeration_filter
      if @user.admin
        { }
      else
        enumeration_filter
      end
    end

    def enumeration_filter
      { }
    end

    def model
      self.class.model
    end

    attr_accessor :request_attrs

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
