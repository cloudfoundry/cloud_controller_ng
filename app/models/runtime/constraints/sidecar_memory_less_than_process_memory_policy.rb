class SidecarMemoryLessThanProcessMemoryPolicy
  attr_reader :new_memory, :processes, :message

  # memory represents the amount of memory to add to the total sidecar amount
  def initialize(processes, new_memory=0)
    @new_memory = new_memory || 0
    @processes = Array(processes)
  end

  def valid?
    processes.each do |process|
      total_sidecar_memory = process.sidecars.select(&:memory).sum(&:memory) + new_memory

      if total_sidecar_memory >= process.memory
        @message = "The memory allocation defined is too large to run with the dependent \"#{process.type}\" process"
        return false
      end
    end
    true
  end
end
