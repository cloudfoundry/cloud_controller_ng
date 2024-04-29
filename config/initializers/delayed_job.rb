module CCInitializers
  def self.delayed_job(_, _)
    ::Delayed::Worker.backend = :sequel
  end
end
