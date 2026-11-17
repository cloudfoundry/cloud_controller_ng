require 'active_model'
require 'services/service_brokers/v2/broker_url'
require 'services/service_brokers/v2/broker_egress_policy'

module VCAP::CloudController::Validators
  class BrokerEgressValidator < ActiveModel::Validator
    def validate(record)
      return if record.errors[:url].any?

      broker_url = VCAP::Services::ServiceBrokers::V2::BrokerUrl.parse!(record.url)
      VCAP::Services::ServiceBrokers::V2::BrokerEgressPolicy.from_config.resolve_and_validate!(broker_url)
    rescue VCAP::Services::ServiceBrokers::V2::BrokerUrl::InvalidUrl => e
      record.errors.add(:url, e.message)
    rescue VCAP::Services::ServiceBrokers::V2::BrokerEgressPolicy::DestinationDenied
      record.errors.add(:url, 'must not resolve to a private or reserved IP address')
    rescue VCAP::Services::ServiceBrokers::V2::BrokerEgressPolicy::ResolutionFailed
      record.errors.add(:url, 'Host could not be resolved')
    end
  end
end
