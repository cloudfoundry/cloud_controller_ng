module VCAP::CloudController
  class PrivateStacksController < RestController::ModelController
    def self.model
      Stack
    end

    define_attributes do
      attribute :name, String
      attribute :description, String, default: nil
      attribute :is_private, Message::Boolean, exclude_in: [:create, :update]

      to_many :organizations
      to_many :spaces
    end

    query_parameters :name

    define_messages
    define_routes

    def create
      json_msg = self.class::CreateMessage.decode(body)
      @request_attrs = json_msg.extract(stringify_keys: true)
      logger.debug 'cc.create', model: self.class.model_class_name, attributes: redact_attributes(:create, request_attrs)

      add_warning('Specified is_private flag ignored.  Set to true.') if @request_attrs['is_private'] == false
      attrs = @request_attrs.dup.merge({ 'is_private' => true })

      before_create

      private_stack = model.create_from_hash(attrs)
      validate_access(:create, private_stack, attrs)

      after_create(private_stack)
      [
        HTTP::CREATED,
        { 'Location' => "#{self.class.path}/#{private_stack.guid}" },
        object_renderer.render_json(self.class, private_stack, @opts)
      ]
    end

    def delete(guid)
      do_delete(find_guid_and_validate_access(:delete, guid))
    end

    def self.translate_validation_exception(e, attributes)
      name_errors = e.errors.on(:name)
      if name_errors && name_errors.include?(:unique)
        CloudController::Errors::ApiError.new_from_details('StackNameTaken', attributes['name'])
      else
        CloudController::Errors::ApiError.new_from_details('StackInvalid', e.errors.full_messages)
      end
    end
  end
end
