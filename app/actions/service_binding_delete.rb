class ServiceBindingDelete
  def initialize(service_binding_dataset)
    @service_binding_dataset = service_binding_dataset
  end

  def delete
    service_binding_dataset.destroy
  end

  private

  attr_reader :service_binding_dataset
end
