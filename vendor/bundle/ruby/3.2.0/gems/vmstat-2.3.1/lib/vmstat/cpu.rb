module Vmstat
  # Gathered cpu performance statistics snapshot.
  # @attr [Fixnum] num
  #   The number of the cpu starting at 0 for the first cpu.
  # @attr [Fixnum] user
  #   Current counter of ticks spend in user. The counter can overflow.
  # @attr [Fixnum] system
  #   Current counter of ticks spend in system. The counter can overflow.
  # @attr [Fixnum] nice
  #   Current counter of ticks spend in nice. The counter can overflow.
  # @attr [Fixnum] idle
  #   Current counter of ticks spend in idle. The counter can overflow.
  class Cpu < Struct.new(:num, :user, :system, :nice, :idle)
  end
end
