RSpec.shared_examples 'delayed job' do |job_class|
  raise 'Please provide a job_class argument' unless job_class

  describe 'behaves like a delayed job' do
    it 'does not store complicated objects' do
      job = create_job(job_class)

      serialized = job.to_yaml

      complicated_objects_count = serialized.scan('!ruby/object').count
      expect(complicated_objects_count).to eq(1),
        "Expected to get only single complicated object ('!ruby/object')\n" \
          "But gotten: #{complicated_objects_count}\n" \
          "Serialized job:\n" +
          serialized
    end

    def create_job(job_class)
      params = job_class.instance_method(:initialize).parameters
      args = []
      kwargs = {}
      block = nil
      params.each do |(kind, name)|
        if kind == :keyreq
          kwargs[name] = :"#{name}"
        elsif kind == :key
        elsif kind == :block
          block = -> {}
        else
          args << :"#{name}"
        end
      end

      return job_class.new(*args, **kwargs, &block) if block && !kwargs.empty?
      return job_class.new(*args, &block) if block
      return job_class.new(*args, **kwargs) if !kwargs.empty?

      job_class.new(*args)
    end
  end
end
