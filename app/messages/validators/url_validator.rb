require 'active_model'
require 'cloud_controller/domain_decorator'

module VCAP::CloudController::Validators
  class UrlValidator < ActiveModel::Validator
    def validate(record)
      if URI::DEFAULT_PARSER.make_regexp(['https', 'http']).match?(record.url.to_s)
        record.errors.add(:url, 'must not contain authentication') if URI(record.url).user
      else
        record.errors.add(:url, "'#{record.url}' must be a valid url")
      end
    end
  end
end
