require 'presenters/api/job_presenter'

module VCAP::CloudController::RestController
  # Wraps models and presents collection and per object rest end points
  class ModelController < BaseController
    include Routes

    CENSORED_MESSAGE = 'PRIVATE DATA HIDDEN'.freeze

    attr_reader :object_renderer, :collection_renderer

    def inject_dependencies(dependencies)
      super
      @object_renderer = dependencies.fetch(:object_renderer)
      @collection_renderer = dependencies.fetch(:collection_renderer)
    end

    # Create operation
    def create
      json_msg = self.class::CreateMessage.decode(body)

      @request_attrs = json_msg.extract(stringify_keys: true)

      logger.debug 'cc.create', model: self.class.model_class_name, attributes: redact_attributes(:create, request_attrs)

      before_create

      obj = nil
      model.db.transaction do
        obj = model.create_from_hash(request_attrs)
        validate_access(:create, obj, request_attrs)
      end

      after_create(obj)

      [
        HTTP::CREATED,
        { 'Location' => "#{self.class.path}/#{obj.guid}" },
        object_renderer.render_json(self.class, obj, @opts)
      ]
    end

    # Read operation
    #
    # @param [String] guid The GUID of the object to read.
    def read(guid)
      obj = find_guid(guid)
      validate_access(:read, obj)
      object_renderer.render_json(self.class, obj, @opts)
    end

    # Update operation
    #
    # @param [String] guid The GUID of the object to update.
    def update(guid)
      json_msg = self.class::UpdateMessage.decode(body)
      @request_attrs = json_msg.extract(stringify_keys: true)
      logger.debug 'cc.update', guid: guid, attributes: redact_attributes(:update, request_attrs)
      raise InvalidRequest unless request_attrs

      obj = find_guid(guid)

      before_update(obj)

      model.db.transaction do
        obj.lock!
        validate_access(:read_for_update, obj, request_attrs)
        obj.update_from_hash(request_attrs)
        validate_access(:update, obj, request_attrs)
      end

      after_update(obj)

      [HTTP::CREATED, object_renderer.render_json(self.class, obj, @opts)]
    end

    def do_delete(obj)
      raise_if_has_dependent_associations!(obj) if v2_api? && !recursive_delete?
      model_deletion_job = Jobs::Runtime::ModelDeletion.new(obj.class, obj.guid)
      enqueue_deletion_job(model_deletion_job)
    end

    def enqueue_deletion_job(deletion_job)
      if async?
        job = Jobs::Enqueuer.new(deletion_job, queue: 'cc-generic').enqueue
        [HTTP::ACCEPTED, JobPresenter.new(job).to_json]
      else
        deletion_job.perform
        [HTTP::NO_CONTENT, nil]
      end
    end

    # Enumerate operation
    def enumerate
      validate_access(:index, model)

      collection_renderer.render_json(
        self.class,
        enumerate_dataset,
        self.class.path,
        @opts,
        params,
      )
    end

    def get_filtered_dataset_for_enumeration(model, ds, qp, opts)
      Query.filtered_dataset_from_query_params(model, ds, qp, opts)
    end

    # Enumerate the related objects to the one with the given guid.
    #
    # @param [String] guid The GUID of the object for which to enumerate related
    # objects.
    #
    # @param [Symbol] name The name of the relation to enumerate.
    def enumerate_related(guid, name)
      obj = find_guid(guid)
      validate_access(:read, obj)

      associated_model = obj.class.association_reflection(name).associated_class

      associated_controller = VCAP::CloudController.controller_from_model_name(associated_model)

      associated_path = "#{self.class.url_for_guid(guid)}/#{name}"

      validate_access(:index, associated_model, { related_obj: obj, related_model: model })

      filtered_dataset =
        Query.filtered_dataset_from_query_params(
          associated_model,
          obj.user_visible_relationship_dataset(name,
                                                VCAP::CloudController::SecurityContext.current_user,
                                                SecurityContext.admin?),
          associated_controller.query_parameters,
          @opts
        )

      associated_controller_instance = CloudController::ControllerFactory.new(@config, @logger, @env, @params, @body, @sinatra).create_controller(associated_controller)

      associated_controller_instance.collection_renderer.render_json(
        associated_controller,
        filtered_dataset,
        associated_path,
        @opts,
        {}
      )
    end

    # Add a related object.
    #
    # @param [String] guid The GUID of the object for which to add a related
    # object.
    #
    # @param [Symbol] name The name of the relation.
    #
    # @param [String] other_guid The GUID of the object to add to the relation
    def add_related(guid, name, other_guid)
      do_related('add', guid, name, other_guid)
    end

    # Remove a related object.
    #
    # @param [String] guid The GUID of the object for which to delete a related
    # object.
    #
    # @param [Symbol] name The name of the relation.
    #
    # @param [String] other_guid The GUID of the object to delete from the
    # relation.
    def remove_related(guid, name, other_guid)
      do_related('remove', guid, name, other_guid)
    end

    # Add or Remove a related object.
    #
    # @param [String] verb The type of operation to perform.
    #
    # @param [String] guid The GUID of the object for which to perform
    # the requested operation.
    #
    # @param [Symbol] name The name of the relation.
    #
    # @param [String] other_guid The GUID of the object to be "verb"ed to the
    # relation.
    def do_related(verb, guid, name, other_guid)
      logger.debug "cc.association.#{verb}", guid: guid, assocation: name, other_guid: other_guid

      singular_name = name.to_s.singularize

      @request_attrs = { singular_name => other_guid }

      obj = find_guid(guid)

      before_update(obj)

      model.db.transaction do
        validate_access(:read_for_update, obj, request_attrs)
        obj.send("#{verb}_#{singular_name}_by_guid", other_guid)
        validate_access(:update, obj, request_attrs)
      end

      after_update(obj)

      return [HTTP::NO_CONTENT] if verb == 'remove'
      [HTTP::CREATED, object_renderer.render_json(self.class, obj, @opts)]
    end

    # Validate that the current logged in user can have access to the target object.
    #
    # Raises an exception if the user does not have rights to perform
    # the operation on the object.
    #
    # @param [Symbol] op The type of operation to check for access
    #
    # @param [Object] obj The object for which to validate access.
    #
    # @param [User] user The user for which to validate access.
    #
    # @param [Roles] The roles for the current user or client.
    def validate_access(op, obj, *args)
      if @access_context.cannot?("#{op}_with_token".to_sym, obj)
        if obj.is_a? Class
          obj = obj.to_s
        end
        logger.info('allowy.access-denied.insufficient-scope', op: "#{op}_with_token", obj: obj, user: user, roles: roles)
        raise VCAP::Errors::ApiError.new_from_details('InsufficientScope')
      end

      if @access_context.cannot?(op, obj, *args)
        if obj.is_a? Class
          obj = obj.to_s
        end
        logger.info('allowy.access-denied.not-authorized', op: op, obj: obj, user: user, roles: roles)
        raise VCAP::Errors::ApiError.new_from_details('NotAuthorized')
      end
    end

    # The model associated with this api endpoint.
    #
    # @return [Sequel::Model] The model associated with this api endpoint.
    def model
      self.class.model
    end

    def redact_attributes(op, request_attributes)
      request_attributes.dup.tap do |changes|
        changes.keys.each do |key|
          attrib = self.class.attributes[key.to_sym]
          changes[key] = CENSORED_MESSAGE if attrib && attrib.redact_in?(op)
        end
      end
    end

    private

    def enumerate_dataset
      qp = self.class.query_parameters
      visible_objects = model.user_visible(VCAP::CloudController::SecurityContext.current_user, SecurityContext.admin?)
      filtered_objects = filter_dataset(visible_objects)
      get_filtered_dataset_for_enumeration(model, filtered_objects, qp, @opts)
    end

    def filter_dataset(dataset)
      dataset
    end

    def raise_if_has_dependent_associations!(obj)
      associations = obj.class.associations.select do |association|
        if obj.class.association_dependencies_hash[association]
          if obj.class.association_dependencies_hash[association] == :destroy
            obj.has_one_to_many?(association) || obj.has_one_to_one?(association)
          end
        end
      end

      if associations.any?
        raise VCAP::Errors::ApiError.new_from_details('AssociationNotEmpty', associations.join(', '), obj.class.table_name)
      end
    end

    # Find an object and validate that the current user has rights to
    # perform the given operation on that instance.
    #
    # Raises an exception if the object can't be found or if the current user
    # doesn't have access to it.
    #
    # @param [Symbol] op The type of operation to check for access
    #
    # @param [String] guid The GUID of the object to find.
    #
    # @return [Sequel::Model] The sequel model for the object, only if
    # the use has access.
    def find_guid_and_validate_access(op, guid, find_model=model)
      obj = find_guid(guid, find_model)
      validate_access(op, obj)
      obj
    end

    def find_guid(guid, find_model=model)
      obj = find_model.find(guid: guid)
      raise self.class.not_found_exception(guid) if obj.nil?
      obj
    end

    class << self
      include VCAP::CloudController

      attr_accessor :attributes
      attr_accessor :to_many_relationships
      attr_accessor :to_one_relationships

      # path_guid
      #
      # @return [String] The path/route to an instance of this class.
      def path_guid
        "#{path}/:guid"
      end

      # Return the url for a specific guid
      #
      # @return [String] The url for a specific instance of this class.
      def url_for_guid(guid)
        "#{path}/#{guid}"
      end

      # Model associated with this rest/api endpoint
      #
      # @param [String] name The base name of the model class.
      #
      # @return [Sequel::Model] The class of the model associated with
      # this rest endpoint.
      def model(name=nil)
        @model ||= VCAP::CloudController.const_get(model_class_name(name))
      end

      # Get and set the model class name associated with this rest/api endpoint.
      #
      # @param [String] name The model class name associated with this rest/api
      # endpoint.
      #
      # @return [String] The class name of the model associated with
      # this rest endpoint.
      def model_class_name(name=nil)
        @model_class_name = name if name
        @model_class_name ||= guess_model_class_name
      end

      def guess_model_class_name
        class_basename.sub(/Controller$/, '').singularize
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
      def not_found_exception(guid)
        Errors::ApiError.new_from_details(not_found_exception_name, guid)
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
