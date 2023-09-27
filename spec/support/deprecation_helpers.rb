module DeprecationHelpers
  def it_should_be_removed(by:, explanation:)
    it 'is deprecated and should be removed' do
      skip 'Ignoring time bomb tests' if ENV['SKIP_TIME_BOMBS']
      raise(explanation) if Date.today >= Date.parse(by)
    end
  end
end
