# frozen_string_literal: true

require 'fog/core'
require 'fog/json'
require File.expand_path('../aliyun/version', __FILE__)

module Fog
  module Aliyun
    extend Fog::Provider

    # Services
    autoload :Compute,          File.expand_path('../aliyun/compute', __FILE__)
    autoload :Storage,          File.expand_path('../aliyun/storage', __FILE__)

    service(:compute, 'Compute')
    service(:storage, 'Storage')
  end
end
