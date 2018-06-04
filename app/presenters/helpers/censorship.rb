module VCAP::CloudController
  module Presenters
    module Censorship
      PRIVATE_DATA_HIDDEN = 'PRIVATE DATA HIDDEN'.freeze
      PRIVATE_DATA_HIDDEN_BRACKETS = '[PRIVATE DATA HIDDEN]'.freeze
      PRIVATE_DATA_HIDDEN_LIST = '[PRIVATE DATA HIDDEN IN LISTS]'.freeze

      REDACTED_CREDENTIAL = '***'.freeze

      REDACTED = 'REDACTED'.freeze
      REDACTED_BRACKETS = '[REDACTED]'.freeze
    end
  end
end
