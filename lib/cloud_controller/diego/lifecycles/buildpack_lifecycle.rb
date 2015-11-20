module VCAP::CloudController
  class BuildpackLifecycle
    def initialize(package, staging_message)
      @staging_message = staging_message
      @package = package

      raise 'Cannot stage package whose type is not bits.' if package.type != PackageModel::BITS_TYPE
    end

    def create_lifecycle_data_model(droplet)
      VCAP::CloudController::BuildpackLifecycleDataModel.create(
        buildpack: @staging_message.lifecycle['data']['buildpack'],
        stack: requested_stack,
        droplet: droplet
      )
    end

    def staging_environment_variables
      {
        'CF_STACK' => staging_stack
      }
    end

    def pre_known_receipt_information
      {
        buildpack_receipt_buildpack_guid: buildpack_info.buildpack_record.try(:guid),
        buildpack_receipt_stack_name: staging_stack
      }
    end

    def staging_stack
      requested_stack || VCAP::CloudController::Stack.default.name
    end

    def buildpack_info
      @buildpack_info ||= VCAP::CloudController::BuildpackRequestValidator.new(buildpack: buildpack_to_use).tap do |buildpack_info|
        unprocessable!(buildpack_info.errors.full_messages) unless buildpack_info.valid?
      end
    end

    private

    def buildpack_to_use
      requested_buildpack? ? buildpack_data.buildpack : @package.app.lifecycle_data.buildpack
    end

    def requested_buildpack?
      staging_message.requested?(:lifecycle)
    end

    def buildpack_data
      @buildpack_data ||= VCAP::CloudController::BuildpackLifecycleDataMessage.new(staging_message.lifecycle_data.symbolize_keys)
    end

    def requested_stack
      @staging_message.lifecycle.try(:[], 'data').try(:[], 'stack')
    end

    # TODO: should not throw api error this deep, move user input validation to controller
    def unprocessable!(message)
      raise VCAP::Errors::ApiError.new_from_details('UnprocessableEntity', message)
    end

    attr_reader :staging_message
  end
end
