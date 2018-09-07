module TimeUtils
  def self.to_nanoseconds(time)
    time.to_i * 10**9 + time.nsec
  end
end
