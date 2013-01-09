# Copyright (c) 2009-2012 VMware, Inr.

module VCAP::CloudController::RestController

  # Wraps models and presents collection and per object rest end points
  class ModelController < Base
    include Routes

    # Create operation
    def create
      json_msg = self.class::CreateMessage.decode(body)
      @request_attrs = json_msg.extract(:stringify_keys => true)
      raise InvalidRequest unless request_attrs

      model.db.transaction do
        logger.debug "create: #{request_attrs}"
        obj = model.create_from_hash(request_attrs)
        validate_access(:create, obj, user, roles)
        [
          HTTP::CREATED,
          { "Location" => "#{self.class.path}/#{obj.guid}" },
          serialization.render_json(self.class, obj, @opts)
        ]
      end
    end

    # Read operation
    #
    # @param [String] id The GUID of the object to read.
    def read(id)
      logger.debug "read: #{id}"
      obj = find_id_and_validate_access(:read, id)
      serialization.render_json(self.class, obj, @opts)
    end

    # Update operation
    #
    # @param [String] id The GUID of the object to update.
    def update(id)
      obj = find_id_and_validate_access(:update, id)
      json_msg = self.class::UpdateMessage.decode(body)
      @request_attrs = json_msg.extract(:stringify_keys => true)
      raise InvalidRequest unless request_attrs
      logger.debug "update: #{id} #{request_attrs}"

      changes = {}
      model.db.transaction do
        obj.update_from_hash(request_attrs)
        changes = obj.previous_changes || {}
        obj.save
      end

      after_update(obj, changes) if respond_to?(:after_update)
      after_modify(obj)
      [HTTP::CREATED, serialization.render_json(self.class, obj, @opts)]
    end

    # Delete operation
    #
    # @param [String] id The GUID of the object to delete.
    def delete(id)
      logger.debug "delete: #{id}"
      obj = find_id_and_validate_access(:delete, id)
      obj.destroy
      [ HTTP::NO_CONTENT, nil ]
    end

    # Enumerate operation
    def enumerate
      raise NotAuthenticated unless user || roles.admin?
      ds = model.user_visible
      logger.debug "enumerate: #{ds.sql}"
      qp = self.class.query_parameters
      ds = Query.filtered_dataset_from_query_params(model, ds, qp, @opts)
      Paginator.render_json(self.class, ds, self.class.path,
                            @opts.merge(:serialization => serialization))
    end

    # Enumerate the related objects to the one with the given id.
    #
    # @param [String] id The GUID of the object for which to enumerate related
    # objects.
    #
    # @param [Symbol] name The name of the relation to enumerate.
    def enumerate_related(id, name)
      logger.debug "enumerate_related: #{id} #{name}"
      obj = find_id_and_validate_access(:read, id)

      a_model = model.association_reflection(name).associated_class
      a_controller = VCAP::CloudController.controller_from_model_name(a_model)
      ar = model.association_reflection(name)
      a_path = "#{self.class.url_for_id(id)}/#{name}"

      f_key = ar[:reciprocal]
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
      logger.debug "#{verb}_related: #{id} #{name}"
      singular_name = "#{name.to_s.singularize}"
      @request_attrs = { singular_name => other_id }
      obj = find_id_and_validate_access(:update, id)
      obj.send("#{verb}_#{singular_name}_by_guid", other_id)
      after_modify(obj)
      [HTTP::CREATED, serialization.render_json(self.class, obj, @opts)]
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
      logger.debug("find_id_and_validate_access: #{op} #{id}")
      obj = model.find(:guid => id)
      logger.debug("found: #{op} #{id}")
      if obj
        validate_access(op, obj, user, roles)
      else
        raise self.class.not_found_exception.new(id) if obj.nil?
      end
      logger.debug("find_id_and_validate_access OK: #{op} #{id}")
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
    #
    # @param [Roles] The roles for the current user or client.
    def validate_access(op, obj, user, roles)
      logger.debug("validate access: #{op} #{obj.guid}")
      user_perms = Permissions.permissions_for(obj, user, roles)
      unless self.class.op_allowed_by?(op, user_perms)
        raise NotAuthenticated if user.nil? && roles.none?
        raise NotAuthorized
      end
      logger.debug("validate access OK: #{op} #{obj.guid}")
    end

    # The model associated with this api endpoint.
    #
    # @return [Sequel::Model] The model associated with this api endpoint.
    def model
      self.class.model
    end

    def serialization
      self.class.serialization
    end

    private
    # Hook called at the end of +update+, +add_related+ and +remove_related+
    # The default behavior is to do nothing.
    # @param [Models::(model_class_name)] obj
    def after_modify(obj)
    end

    class << self
      include VCAP::CloudController

      attr_accessor :attributes
      attr_accessor :to_many_relationships
      attr_accessor :to_one_relationships

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
        @model ||= Models.const_get(name)
      end

      # Get and set the model class name associated with this rest/api endpoint.
      #
      # @param [String] name The model class name associated with this rest/api
      # endpoint.
      #
      # @return [String] The class name of the model associated with
      # this rest endpoint.
      def model_class_name(name = nil)
        @model_class_name = name if name
        @model_class_name || class_basename
      end

      def serialization(klass = nil)
        @serialization = klass if klass
        @serialization || ObjectSerialization
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

      # Start the DSL for defining attributes.  This is used inside
      # the api controller classes.
      def define_attributes(&blk)
        k = Class.new do
          include ControllerDSL
        end

        k.new(self).instance_eval(&blk)
      end
    end
  end
end
