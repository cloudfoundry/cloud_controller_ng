module VCAP::CloudController
  module ServiceInstanceCreateMixin
    private

    def validation_error!(error, name:)
      if error.errors.on(:name)&.include?(:unique)
        error!("The service instance name is taken: #{name}")
      end
      error!(error.message)
    end
  end
end
