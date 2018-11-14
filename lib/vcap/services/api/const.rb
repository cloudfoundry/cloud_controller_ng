# Copyright (c) 2009-2011 VMware, Inc.
module VCAP
  module Services
    module Api
      GATEWAY_TOKEN_HEADER = 'X-VCAP-Service-Token'.freeze
      SERVICE_LABEL_REGEX  = /^\S+-\S+$/.freeze
    end
  end
end
