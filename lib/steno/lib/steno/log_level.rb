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

  def to_s
    @name.to_s
  end

  def <=>(other)
    @priority <=> other.priority
  end
end
