module Fog
  module Compute
    class Aliyun
      class Flavors < Fog::Collection
        model Fog::Compute::Aliyun::Flavor
        def all
          data = Fog::JSON.decode(service.list_server_types.body)['InstanceTypes']['InstanceType']
          load(data)
        end
      end
    end
  end
end
