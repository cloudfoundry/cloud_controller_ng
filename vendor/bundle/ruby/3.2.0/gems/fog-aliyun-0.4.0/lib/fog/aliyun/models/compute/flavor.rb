require 'fog/core/model'

module Fog
  module Compute
    class Aliyun
      class Flavor < Fog::Model
        attribute :base_line_credit, aliases: 'BaseLineCredit'
        attribute :cpu_core_count, aliases: 'CpuCoreCount'
        attribute :eni_private_ip_quantitiy, aliases: 'EniPrivateIpAddressQuantity'
        attribute :eni_quantity, aliases: 'EniQuantity'
        attribute :gpu_amount, aliases: 'GPUAmount'
        attribute :gpu_spec, aliases: 'GPUSpec'
        attribute :intial_credit, aliases: 'IntialCredit'
        attribute :instance_bandwidth_rx, aliases: 'InstanceBandwidthRx'
        attribute :instance_bandwidth_tx, aliases: 'InstanceBandwidthTx'
        attribute :instance_family_level, aliases: 'InstanceFamilyLevel'
        attribute :instance_pps_rx, aliases: 'InstancePpsRx'
        attribute :instance_pps_tx, aliases: 'InstancePpsTx'
        attribute :instance_type_family, alieses: 'InstanceTypeFamily'
        attribute :instance_type_id, aliases: 'InstanceTypeId'
        attribute :local_storage_amount, aliases: 'LocalStorageAmount'
        attribute :local_storage_capacity, aliases: 'LocalStorageCapacity'
        attribute :local_storage_category, aliases: 'LocalStorageCategory'
        attribute :memory_size, alieses: 'MemorySize'
      end
    end
  end
end
