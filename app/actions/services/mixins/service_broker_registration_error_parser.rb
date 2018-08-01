module VCAP::CloudController
  module ServiceBrokerRegistrationErrorParser
    def get_exception_from_errors(registration)
      errors = registration.errors
      broker = registration.broker

      if errors.on(:broker_url) && errors.on(:broker_url).include?(:url)
        CloudController::Errors::ApiError.new_from_details('ServiceBrokerUrlInvalid', broker.broker_url)
      elsif errors.on(:broker_url) && errors.on(:broker_url).include?(:unique)
        CloudController::Errors::ApiError.new_from_details('ServiceBrokerUrlTaken', broker.broker_url)
      elsif errors.on(:name) && errors.on(:name).include?(:unique)
        CloudController::Errors::ApiError.new_from_details('ServiceBrokerNameTaken', broker.name)
      elsif errors.on(:services)
        CloudController::Errors::ApiError.new_from_details('ServiceBrokerInvalid', errors.on(:services))
      else
        CloudController::Errors::ApiError.new_from_details('ServiceBrokerInvalid', errors.full_messages)
      end
    end
  end
end
