module VCAP::CloudController
  class IncludeAppProcessDecorator
    class << self
      def match?(include)
        include&.any? { |i| %w(process).include?(i) }
      end

      def decorate(hash, apps)
        hash[:included] ||= {}

        processes = ProcessModel.where(app: apps).order(:created_at).
                    eager(Presenters::V3::ProcessPresenter.associated_resources).all

        hash[:included][:processes] = processes.map { |process| Presenters::V3::ProcessPresenter.new(process).to_hash }
        hash
      end
    end
  end
end
