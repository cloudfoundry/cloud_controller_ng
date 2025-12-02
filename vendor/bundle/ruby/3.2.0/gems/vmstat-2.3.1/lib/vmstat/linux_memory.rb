# @attr [Fixnum] available
#   The estimated available memory (linux)
#   See: https://git.kernel.org/cgit/linux/kernel/git/torvalds/linux.git/commit/?id=34e431b0ae398fc54ea69ff85ec700722c9da773
class Vmstat::LinuxMemory < Vmstat::Memory
  attr_accessor :available

  # Calculate the available bytes based of the active pages.
  # @return [Fixnum] active bytes
  def available_bytes
    available * pagesize
  end
end

