require "spec_helper"

module VCAP::CloudController
  describe Stack, type: :model do
    it_behaves_like "a CloudController model", {
      :required_attributes        => [:name, :description],
      :unique_attributes          => :name,
      :stripped_string_attributes => :name,
      :one_to_zero_or_more => {
        :apps              => {
          :delete_ok => true,
          :create_for => lambda { |stack| AppFactory.make(:stack => stack) }
        },
      },
    }

    describe ".configure" do
      context "with valid config" do
        let(:file) { File.join(fixture_path, "config/stacks.yml") }

        it "can load" do
          described_class.configure(file)
        end
      end

      context "with invalid config" do
        let(:file) { File.join(fixture_path, "config/invalid_stacks.yml") }

        {:default => "default => Missing key",
         :stacks => "name => Missing key"
        }.each do |key, expected_error|
          it "requires #{key} (validates via '#{expected_error}')" do
            expect {
              described_class.configure(file)
            }.to raise_error(Membrane::SchemaValidationError, /#{expected_error}/)
          end
        end
      end

      describe "config/stacks.yml" do
        let(:file) { File.join(fixture_path, "config/stacks.yml") }

        it "can load" do
          described_class.configure(file)
        end
      end
    end

    describe ".populate" do
      context "when config was not set" do
        before { described_class.configure(nil) }

        it "raises config not specified error" do
          expect {
            described_class.default
          }.to raise_error(described_class::MissingConfigFileError)
        end
      end

      context "when config was set" do
        let(:file) { File.join(fixture_path, "config/stacks.yml") }

        before { described_class.configure(file) }

        context "when there are no stacks" do
          before { Stack.dataset.destroy }

          it "creates them all" do
            described_class.populate

            cider = described_class.find(:name => "cider")
            expect(cider.description).to eq("cider-description")

            default_stack = described_class.find(:name => "default-stack-name")
            expect(default_stack.description).to eq("default-stack-description")
          end

          context "when there are existing stacks" do
            before { Stack.populate }

            it "should not create duplicates" do
              expect { Stack.populate }.not_to change { Stack.count }
            end

            context "and the config file would change an existing stack" do
              it "should warn" do
                cider = Stack.find(name: "cider")
                cider.description = "cider-description has changed"
                cider.save


                mock_logger = double
                Steno.stub(:logger).and_return(mock_logger)

                mock_logger.should_receive(:warn).with("stack.populate.collision", "name" => "cider", "description" => "cider-description")

                Stack.populate
              end
            end
          end
        end
      end
    end

    describe ".default" do
      let(:file) { File.join(fixture_path, "config/stacks.yml") }
      before { described_class.configure(file) }

      context "when config was not set" do
        before { described_class.configure(nil) }

        it "raises config not specified error" do
          expect {
            described_class.default
          }.to raise_error(described_class::MissingConfigFileError)
        end
      end

      context "when config was set" do
        before { Stack.dataset.destroy }

        context "when stack is found with default name" do
          before { Stack.make(:name => "default-stack-name") }

          it "returns found stack" do
            described_class.default.name.should == "default-stack-name"
          end
        end

        context "when stack is not found with default name" do
          it "raises MissingDefaultStack" do
            expect {
              described_class.default
            }.to raise_error(described_class::MissingDefaultStackError, /default-stack-name/)
          end
        end
      end
    end

    describe "#destroy" do
      let(:stack) { Stack.make }

      it "destroys the apps" do
        app = AppFactory.make(:stack => stack)
        expect { stack.destroy(savepoint: true) }.to change { App.where(:id => app.id).count }.by(-1)
      end
    end
  end
end
