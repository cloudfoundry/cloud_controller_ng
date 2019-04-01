module VCAP::CloudController
  module Diego
    class BbsEnvironmentBuilder
      def self.build(environment)
        env = NormalEnvHashToDiegoEnvArrayPhilosopher.muse(environment)
        env.map { |i| ::Diego::Bbs::Models::EnvironmentVariable.new(name: i['name'], value: i['value']) }
      end
    end
  end
end
