module VCAP::CloudController
  class BuildpacksController < RestController::ModelController
    def self.dependencies
      [:buildpack_blobstore, :upload_handler]
    end

    define_attributes do
      attribute :name, String
      attribute :position, Integer, default: 0
      attribute :enabled, Message::Boolean, default: true
      attribute :locked, Message::Boolean, default: false
    end

    query_parameters :name

    def initialize(*args)
      super
      @opts.merge!(order_by: :position)
    end

    def self.translate_validation_exception(e, attributes)
      buildpack_errors = e.errors.on(:name)
      if buildpack_errors && buildpack_errors.include?(:unique)
        CloudController::Errors::ApiError.new_from_details('BuildpackNameTaken', attributes['name'])
      else
        CloudController::Errors::ApiError.new_from_details('BuildpackInvalid', e.errors.full_messages)
      end
    end

    def create
      json_msg = self.class::CreateMessage.decode(body)
      @request_attrs = json_msg.extract(stringify_keys: true)
      logger.debug 'cc.create', model: self.class.model_class_name, attributes: redact_attributes(:create, request_attrs)

      before_create

      position = request_attrs['position']

      buildpack = nil
      model.db.transaction do
        buildpack = model.create_from_hash(request_attrs.except('position'))
        validate_access(:create, buildpack, request_attrs)
        Locking[name: 'buildpacks'].lock!

        buildpack.move_to(position)
      end

      after_create(buildpack)
      [
        HTTP::CREATED,
        { 'Location' => "#{self.class.path}/#{buildpack.guid}" },
        object_renderer.render_json(self.class, buildpack, @opts)
      ]
    end

    def update(guid)
      json_msg = self.class::UpdateMessage.decode(body)
      @request_attrs = json_msg.extract(stringify_keys: true)
      logger.debug 'cc.update', guid: guid, attributes: redact_attributes(:update, request_attrs)
      raise InvalidRequest unless request_attrs

      buildpack = find_guid(guid)
      validate_access(:update, buildpack, request_attrs)

      before_update(buildpack)

      new_position = request_attrs['position']
      model.db.transaction do
        buildpack.lock!
        buildpack.update_from_hash(request_attrs.except('position'))
      end
      model.db.transaction do
        Locking[name: 'buildpacks'].lock!
        buildpack.move_to(new_position) if new_position.present?
      end

      after_update(buildpack)
      [HTTP::CREATED, object_renderer.render_json(self.class, buildpack, @opts)]
    end

    def delete(guid)
      find_guid_and_validate_access(:delete, guid)

      job = Jobs::Runtime::BuildpackDelete.new(guid: guid, timeout: @config.get(:staging, :timeout_in_seconds))
      enqueue_deletion_job(job)
    end

    def self.not_found_exception_name(_model_class)
      'NotFound'
    end

    private

    attr_reader :buildpack_blobstore

    def inject_dependencies(dependencies)
      super
      @buildpack_blobstore = dependencies[:buildpack_blobstore]
    end

    define_messages
    define_routes
  end
end
