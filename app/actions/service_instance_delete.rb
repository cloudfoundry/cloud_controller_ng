require 'actions/service_binding_delete'

class ServiceInstanceDelete
  attr_reader :service_instance_dataset

  def initialize(service_instance_dataset)
    @service_instance_dataset = service_instance_dataset
  end

  def delete
    service_instance_dataset.each do |service_instance|
      ServiceBindingDelete.new.delete(service_instance.service_bindings_dataset)
    end

    service_instance_dataset.destroy
  end
end
