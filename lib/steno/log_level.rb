module Steno
end

class Steno::LogLevel
  include Comparable

  attr_reader :name, :priority

  # @param [String]  name      "info", "debug", etc.
  # @param [Integer] priority  "info" > "debug", etc.
  def initialize(name, priority)
    @name = name
    @priority = priority
  end

  delegate :to_s, to: :@name

  def <=>(other)
    @priority <=> other.priority
  end
end
