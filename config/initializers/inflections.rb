module CCInitializers
  def self.inflections(_)
    ActiveSupport::Inflector.inflections(:en) do |inflect|
      inflect.irregular 'quota', 'quotas'
    end
  end
end
