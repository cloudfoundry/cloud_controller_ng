# Copyright (c) 2009-2012 VMware, Inr.

module VCAP::CloudController::RestController

  # The base class for all api endpoints.
  class Base
    ROUTE_PREFIX = "/v2"

    include VCAP::CloudController
    include VCAP::CloudController::Errors
    include VCAP::RestAPI
    include PermissionManager
    include Messages
    include Routes

    # Tell the PermissionManager the types of operations that can be performed.
    define_permitted_operation :create
    define_permitted_operation :read
    define_permitted_operation :update
    define_permitted_operation :delete
    define_permitted_operation :enumerate

    # Create a new rest api endpoint.
    #
    # @param [Models::User] user The user peforming the rest request.  It may
    # be nil.
    #
    # @param [VCAP::Logger] logger The logger to use during the request.
    #
    # @param [IO] body The request body.
    #
    # @param [Hash] query_params The http query parameters.
    def initialize(logger, body = nil, query_params = {})
      @logger  = logger
      @body    = body
      @opts    = parse_params(query_params)
    end

    # Parses and sanitizes query parameters from the sinatra request.
    #
    # @return [Hash] the parsed parameter hash
    def parse_params(params)
      logger.debug2 "#{log_prefix} parse_params: #{params}"
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

    # Main entry point for the rest routes.  Acts as the final location
    # for catching any unhandled sequel and db exceptions.  By calling
    # translate_and_log_exception, they will get logged so that we can
    # address them and will get converted to a generic invalid request
    # so that they can be investigated and have more accurate error
    # reporting added.
    #
    # @param [Symbol] op The method to dispatch to.
    #
    # @param [Array] args The arguments to the method beign disptched to.
    #
    # @return [Object] Returns an array of [http response code, Header hash,
    # body string], or just a body string.
    def dispatch(op, *args)
      logger.debug2 "#{log_prefix} dispatch: #{op}"
      send(op, *args)
    rescue Sequel::ValidationFailed => e
      raise self.class.translate_validation_exception(e, request_attrs)
    rescue Sequel::DatabaseError => e
      raise self.class.translate_and_log_exception(logger, e)
    end

    # Common managment of quota enforcement.
    #
    # @param [Hash] quota_request_body Hash of the request to send to the
    # remote quota manager.  If nil, indicates that quota enformcement
    # is not necessary.
    #
    # @param [Block] &blk The block to execute with quota enforcement.
    #
    # @return Results of calling the provided block.
    def with_quota_enforcement(quota_request_body, &blk)
      token = QuotaManager.fetch_quota_token(quota_request_body)
      ret = blk.call
      token.commit
      return ret
    rescue QuotaDeclined => e
      raise e
    rescue Exception => e
      token.abandon(e.message) unless token.nil?
      raise e
    end

    # By default, operations do not require quota enformcement.
    # Endpoints are expected to override this method if they need
    # quota enforcement.
    #
    # TODO: once quota is implemented verywhere, take these out
    # for safety.  Err on the side of requring quota check.
    def create_quota_token_request(obj); end
    def update_quota_token_request(obj); end
    def delete_quota_token_request(obj); end

    # Create operation
    def create
      @request_attrs = Yajl::Parser.new.parse(@body)
      raise InvalidRequest unless request_attrs

      model.db.transaction do
        logger.debug2 "#{log_prefix} create: #{request_attrs}"
        obj = model.create_from_hash(request_attrs)
        validate_access(:create, obj, user)

        with_quota_enforcement(create_quota_token_request(obj)) do
          [HTTP::CREATED,
           { "Location" => "#{self.class.path}/#{obj.guid}" },
          ObjectSerialization.render_json(self.class, obj, @opts)]
        end
      end
    end

    # Read operation
    #
    # @param [String] id The GUID of the object to read.
    def read(id)
      logger.debug2 "#{log_prefix} read: #{id}"
      obj = find_id_and_validate_access(:read, id)
      ObjectSerialization.render_json(self.class, obj, @opts)
    end

    # Update operation
    #
    # @param [String] id The GUID of the object to update.
    def update(id)
      obj = find_id_and_validate_access(:update, id)
      @request_attrs = Yajl::Parser.new.parse(@body)
      raise InvalidRequest unless request_attrs
      logger.debug2 "#{log_prefix} update: #{id} #{request_attrs}"

      with_quota_enforcement(update_quota_token_request(obj)) do
        obj.update_from_hash(request_attrs)
        obj.save
        [HTTP::CREATED, ObjectSerialization.render_json(self.class, obj, @opts)]
      end
    end

    # Delete operation
    #
    # @param [String] id The GUID of the object to delete.
    def delete(id)
      logger.debug2 "#{log_prefix} update: #{id}"
      obj = find_id_and_validate_access(:delete, id)

      with_quota_enforcement(delete_quota_token_request(obj)) do
        obj.destroy
        [HTTP::NO_CONTENT, nil]
      end
    end

    # Enumerate operation
    def enumerate
      raise NotAuthenticated unless user
      ds = model.user_visible
      logger.debug2 "#{log_prefix} enumerate: #{ds.sql}"
      qp = self.class.query_parameters
      ds = Query.filtered_dataset_from_query_params(model, ds, qp, @opts)
      Paginator.render_json(self.class, ds, self.class.path, @opts)
    end

    # Enumerate the related objects to the one with the given id.
    #
    # @param [String] id The GUID of the object for which to enumerate related
    # objects.
    #
    # @param [Symbol] name The name of the relation to enumerate.
    def enumerate_related(id, name)
      logger.debug2 "#{log_prefix} enumerate_related: #{id} #{name}"
      obj = find_id_and_validate_access(:read, id)

      a_model = model.association_reflection(name).associated_class
      a_controller = VCAP::CloudController.controller_from_model_name(a_model)
      ar = model.association_reflection(name)
      a_path = "#{self.class.url_for_id(id)}/#{name}"

      f_key = ar[:reciprocol]
      ds = a_model.user_visible.filter(f_key => obj)
      qp = a_controller.query_parameters

      ds = Query.filtered_dataset_from_query_params(a_model, ds, qp, @opts)
      Paginator.render_json(a_controller, ds, a_path, @opts)
    end

    # Add a related object.
    #
    # @param [String] id The GUID of the object for which to add a related
    # object.
    #
    # @param [Symbol] name The name of the relation.
    #
    # @param [String] other_id The GUID of the object to add to the relation
    def add_related(id, name, other_id)
      do_related("add", id, name, other_id)
    end

    # Remove a related object.
    #
    # @param [String] id The GUID of the object for which to delete a related
    # object.
    #
    # @param [Symbol] name The name of the relation.
    #
    # @param [String] other_id The GUID of the object to delete from the
    # relation.
    def remove_related(id, name, other_id)
      do_related("remove", id, name, other_id)
    end

    # Remove a related object.
    #
    # @param [String] verb The type of operation to perform.
    #
    # @param [String] id The GUID of the object for which to perform
    # the requested operation.
    #
    # @param [Symbol] name The name of the relation.
    #
    # @param [String] other_id The GUID of the object to be "verb"ed to the
    # relation.
    def do_related(verb, id, name, other_id)
      logger.debug2 "#{log_prefix} #{verb}_related: #{id} #{name}"
      singular_name = "#{name.to_s.singularize}"
      @request_attrs = { singular_name => other_id }
      obj = find_id_and_validate_access(:update, id)
      obj.send("#{verb}_#{singular_name}_by_guid", other_id)
      [HTTP::CREATED, ObjectSerialization.render_json(self.class, obj, @opts)]
    end

    # Find an object and validate that the current user has rights to
    # perform the given operation on that instance.
    #
    # Raises an exception if the object can't be found or if the current user
    # doesn't have access to it.
    #
    # @param [Symbol] op The type of operation to check for access
    #
    # @param [String] id The GUID of the object to find.
    #
    # @return [Sequel::Model] The sequel model for the object, only if
    # the use has access.
    def find_id_and_validate_access(op, id)
      obj = model.find(:guid => id)
      if obj
        validate_access(op, obj, user)
      else
        raise self.class.not_found_exception.new(id) if obj.nil?
      end
      obj
    end

    # Find an object and validate that the given user has rights
    # to access the instance.
    #
    # Raises an exception if the user does not have rights to peform
    # the operation on the object.
    #
    # @param [Symbol] op The type of operation to check for access
    #
    # @param [Object] obj The object for which to validate access.
    #
    # @param [Models::User] user The user for which to validate access.
    def validate_access(op, obj, user)
      user_perms = Permissions.permissions_for(obj, user)
      unless self.class.op_allowed_by?(op, user_perms)
        raise NotAuthenticated unless user
        raise NotAuthorized
      end
    end

    # Fetch the current active user.  May be nil
    #
    # @return [Models::User] User object for the currently active user
    def user
      VCAP::CloudController::SecurityContext.current_user
    end

    # The model associated with this api endpoint.
    #
    # @return [Sequel::Model] The model associated with this api endpoint.
    def model
      self.class.model
    end

    # The log prefix to use on all log lines.
    #
    # TODO: see if we can dup the logger and add our own prefix.
    #
    # @return [String] The log prefix to use on all log lines.
    def log_prefix
      self.class.class_basename
    end

    # Our logger.
    #
    # @return [VCAP::Logger] The logger.
    def logger
      @logger
    end

    attr_accessor :request_attrs

    class << self
      include VCAP::CloudController

      attr_accessor :attributes
      attr_accessor :to_many_relationships
      attr_accessor :to_one_relationships

      # basename of the class
      #
      # @return [String] basename of the class
      def class_basename
        self.name.split("::").last
      end

      # path
      #
      # @return [String] The path/route to the collection associated with
      # the class.
      def path
        "#{ROUTE_PREFIX}/#{class_basename.underscore.pluralize}"
      end

      # path_id
      #
      # @return [String] The path/route to an instance of this class.
      def path_id
        "#{path}/:guid"
      end

      # Return the url for a specfic id
      #
      # @return [String] The url for a specific instance of this class.
      def url_for_id(id)
        "#{path}/#{id}"
      end

      # Model associated with this rest/api endpoint
      #
      # @param [String] name The base name of the model class.
      #
      # @return [Sequel::Model] The class of the model associated with
      # this rest endpoint.
      def model(name = model_class_name)
        Models.const_get(name)
      end

      # Model class name associated with this rest/api endpoint.
      #
      # @return [String] The class name of the model associated with
      # this rest endpoint.
      def model_class_name
        class_basename
      end

      # Model class name associated with this rest/api endpoint.
      #
      # @return [String] The class name of the model associated with
      def not_found_exception_name
        "#{model_class_name}NotFound"
      end

      # Lookup the not-found exception for this rest/api endpoint.
      #
      # @return [Exception] The vcap not-found exception for this
      # rest/api endpoint.
      def not_found_exception
        Errors.const_get(not_found_exception_name)
      end

      # Get and set the allowed query paramaeters (sent via the q http
      # query parmameter) for this rest/api endpoint.
      #
      # @param [Array] args One or more attributes that can be used
      # as query parameters.
      #
      # @return [Set] If called with no arguments, returns the list
      # of query parameters.
      def query_parameters(*args)
        if args.empty?
          @query_parameters ||= Set.new
        else
          @query_parameters ||= Set.new
          @query_parameters |= Set.new(args.map { |a| a.to_s })
        end
      end

      # Start the DSL for defining attributes.  This is used inside
      # the api controller classes.
      def define_attributes(&blk)
        k = Class.new do
          include ControllerDSL
        end

        k.new(self).instance_eval(&blk)
      end

      # Start the DSL for defining attributes.  This is used inside
      # the api controller classes.
      #
      def translate_and_log_exception(logger, e)
        msg = ["exception not translated: #{e.class} - #{e.message}"]
        msg[0] = msg[0] + ":"
        msg.concat(e.backtrace).join("\\n")
        logger.warn(msg.join("\\n"))
        Errors::InvalidRequest
      end
    end
  end
end
