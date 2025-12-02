module Vmstat
  # In UNIX computing, the system load is a measure of the amount of
  # computational work that a computer system performs. The load average 
  # represents the average system load over a period of time.
  # Source: wikipedia(en).
  # @attr [Float] one_minute The load for the last minute.
  # @attr [Float] five_minutes The load for the last five minutes.
  # @attr [Float] fifteen_minutes The load for the last fifteen minutes.
  class LoadAverage < Struct.new(:one_minute, :five_minutes, :fifteen_minutes)
  end
end
