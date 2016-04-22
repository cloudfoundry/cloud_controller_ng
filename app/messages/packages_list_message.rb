require 'messages/list_message'

module VCAP::CloudController
  class PackagesListMessage < ListMessage
    ALLOWED_KEYS = [:page, :per_page, :states].freeze

    attr_accessor(*ALLOWED_KEYS)

    validates_with NoAdditionalParamsValidator # from BaseMessage

    validates :states, array: true, allow_nil: true

    def initialize(params={})
      super(params.symbolize_keys)
    end

    def self.from_params(params)
      opts = params.dup
      ['states'].each do |attribute|
        to_array! opts, attribute
      end
      new(opts.symbolize_keys)
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
