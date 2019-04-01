module CCInitializers
  def self.delayed_job(_)
    ::Delayed::Worker.backend = :sequel
  end
end
