class SidecarMemoryLessThanProcessMemoryPolicy
  attr_reader :new_memory, :processes, :message

  # memory represents the amount of memory to add to the total sidecar amount
  def initialize(processes, new_memory=0, existing_sidecar=nil)
    @new_memory = new_memory || 0
    @processes = Array(processes)
    @existing_sidecar = existing_sidecar
  end

  def valid?
    processes.each do |process|
      sidecars = process.sidecars
      sidecars = sidecars.reject { |sidecar| sidecar.name == @existing_sidecar.name } if @existing_sidecar
      total_sidecar_memory = sidecars.select(&:memory).sum(&:memory) + new_memory

      if total_sidecar_memory >= process.memory
        @message = "The memory allocation defined is too large to run with the dependent \"#{process.type}\" process"
        return false
      end
    end
    true
  end
end
