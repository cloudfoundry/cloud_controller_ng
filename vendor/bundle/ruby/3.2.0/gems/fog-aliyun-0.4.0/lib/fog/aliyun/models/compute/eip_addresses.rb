# frozen_string_literal: true

require 'fog/core/collection'
require 'fog/aliyun/models/compute/eip_address'

module Fog
  module Compute
    class Aliyun
      class EipAddresses < Fog::Collection
        model Fog::Compute::Aliyun::EipAddress

        def all(filters_arg = {})
          data = Fog::JSON.decode(service.list_eip_addresses(filters_arg).body)['EipAddresses']['EipAddress']
          load(data)
          # load(data['volumeSet'])
          # if server
          #   self.replace(self.select {|volume| volume.server_id == server.id})
          # end
          # self
        end

        def get(allocation_id)
          self.class.new(service: service).all(allocation_id: allocation_id)[0] if allocation_id
        end
      end
    end
  end
end
