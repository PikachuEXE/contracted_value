# frozen_string_literal: true

require "spec_helper"

::RSpec.describe ::ContractedValue::Value do

  shared_examples_for "attribute declaration" do
    let(:value_class) do
      raise "`value_class` absent"
    end

    example "does not raise error when NOT declaring any attribute" do
      expect { value_class }.to_not raise_error
    end

    example "does not raise error when declaring 1 attribute" do
      expect {
        value_class.class_eval do
          attribute(:attribute_1)
        end
      }.to_not raise_error
    end

    example "does not raise error when declaring N attributes with different names" do
      expect {
        value_class.class_eval do
          attribute(:attribute_1)
          attribute(:attribute_2)
        end
      }.to_not raise_error
    end

    example "does raise error when declaring N attributes with the same name" do
      expect {
        value_class.class_eval do
          attribute(:attribute_1)
          attribute(:attribute_2)
          attribute(:attribute_1)
        end
      }.to raise_error(::ContractedValue::Errors::DuplicateAttributeDeclaration)
    end
  end


  describe "attribute declaration" do
    it_behaves_like "attribute declaration" do
      let(:value_class) do
        Class.new(described_class)
      end
    end
  end

  describe "attribute assignment" do
    context "on object initialization" do
      context "with class with no attribute declared with contract" do
        let(:value_class) do
          Class.new(described_class) do
            attribute(:attribute_1)
            attribute(:attribute_2)
          end
        end

        let(:default_inputs) do
          {
            attribute_1: 1,
            attribute_2: 1,
          }
        end

        let(:non_hash) do
          []
        end

        it "does raise error when input is not a hash" do
          aggregate_failures do
            expect {
              value_class.new(
                non_hash,
              )
            }.to raise_error(::ContractedValue::Errors::InvalidInputType)
          end
        end

        it "does not raise error when input is a hash" do
          aggregate_failures do
            expect {
              value_class.new(
                default_inputs,
              )
            }.to_not raise_error
          end
        end

        it "does not raise error when input is a value" do
          aggregate_failures do
            expect {
              value_class.new(
                value_class.new(
                  default_inputs,
                ),
              )
            }.to_not raise_error
          end
        end

        it "does raise error when value of any declared attribute missing from input" do
          aggregate_failures do
            [
              :attribute_1,
              :attribute_2,
            ].each do |attr_name|
              expect {
                value_class.new(
                  default_inputs.dup.tap{|h| h.delete(attr_name)},
                )
              }.to raise_error(::ContractedValue::Errors::MissingAttributeInput)
            end
          end
        end

        it "does not raise error when values of all declared attributes are present, even they are all nil" do
          aggregate_failures do
            [
              :attribute_1,
              :attribute_2,
            ].each do |attr_name|
              expect {
                value_class.new(
                  default_inputs.each_with_object({}) do |(k, _v), h|
                    h[k] = nil
                  end
                )
              }.to_not raise_error
            end
          end
        end
      end

      context "with class with some attributes declared with contract" do
        let(:value_class) do
          Class.new(described_class) do
            attribute(
              :attribute_with_contract_1,
              contract: ::Contracts::Builtin::And[::String, ::Contracts::Builtin::Not[::Contracts::Builtin::Send[:empty?]]],
            )
            attribute(
              :attribute_with_contract_2,
              contract: ::Contracts::Builtin::NatPos,
            )
          end
        end

        let(:default_inputs) do
          {
            attribute_with_contract_1: "yo",
            attribute_with_contract_2: 1,
          }
        end


        it "does not raise error when all values are valid according to contracts" do
          expect {
            value_class.new(
              default_inputs
            )
          }.to_not raise_error
        end

        it "does raise error when any value is invalid according to contracts" do
          aggregate_failures do
            expect {
              value_class.new(
                default_inputs.merge(
                  attribute_with_contract_1: "",
                ),
              )
            }.to raise_error(::ContractedValue::Errors::InvalidAttributeValue)

            expect {
              value_class.new(
                default_inputs.merge(
                  attribute_with_contract_2: 0,
                ),
              )
            }.to raise_error(::ContractedValue::Errors::InvalidAttributeValue)
          end
        end
      end
    end
  end

  describe "attribute input value freezing" do
    let(:value_object) do
      value_class.new(
        a_hash: hash_as_input,
      )
    end

    let(:hash_as_input) do
      {
        hash: hash_as_deep_nested_content,
      }
    end

    let(:hash_as_deep_nested_content) do
      ::Hash.new
    end

    shared_examples "attribute deeply frozen" do
      it "does freeze the new object" do
        expect(value_object).to be_frozen
      end

      it "does freeze the inputs" do
        # Create it just before expectation
        value_object

        expect {
          hash_as_input[:a] = nil
        }.to raise_error(::RuntimeError, /can't modify frozen/)
      end

      it "does deeply freeze the inputs" do
        # Create it just before expectation
        value_object

        expect {
          hash_as_deep_nested_content[:a] = nil
        }.to raise_error(::RuntimeError, /can't modify frozen/)
      end
    end

    shared_examples "attribute shallowly frozen" do
      it "does freeze the new object" do
        expect(value_object).to be_frozen
      end

      it "does freeze the inputs" do
        # Create it just before expectation
        value_object

        expect {
          hash_as_input[:a] = nil
        }.to raise_error(::RuntimeError, /can't modify frozen/)
      end

      it "does not deeply freeze the inputs" do
        # Create it just before expectation
        value_object

        expect {
          hash_as_deep_nested_content[:a] = nil
        }.to_not raise_error
      end
    end

    shared_examples "attribute not frozen" do
      it "does freeze the new object" do
        expect(value_object).to be_frozen
      end

      it "does not freeze the inputs" do
        # Create it just before expectation
        value_object

        expect {
          hash_as_input[:a] = nil
        }.to_not raise_error
      end

      it "does not deeply freeze the inputs" do
        # Create it just before expectation
        value_object

        expect {
          hash_as_deep_nested_content[:a] = nil
        }.to_not raise_error
      end
    end

    context "when an attribute is declared without `refrigeration_mode` option" do
      let(:value_class) do
        Class.new(described_class) do
          attribute(:a_hash)
        end
      end

      it_behaves_like "attribute deeply frozen"
    end

    context "when an attribute is declared with `refrigeration_mode` option (:deep)" do
      let(:value_class) do
        Class.new(described_class) do
          attribute(
            :a_hash,
            refrigeration_mode: :deep,
          )
        end
      end

      it_behaves_like "attribute deeply frozen"
    end

    context "when an attribute is declared with `refrigeration_mode` option (:shallow)" do
      let(:value_class) do
        Class.new(described_class) do
          attribute(
            :a_hash,
            refrigeration_mode: :shallow,
          )
        end
      end

      it_behaves_like "attribute shallowly frozen"
    end

    context "when an attribute is declared with `refrigeration_mode` option (:none)" do
      let(:value_class) do
        Class.new(described_class) do
          attribute(
            :a_hash,
            refrigeration_mode: :none,
          )
        end
      end

      it_behaves_like "attribute not frozen"
    end

    context "when an attribute is declared with invalid `refrigeration_mode` option" do
      let(:value_class) do
        Class.new(described_class) do
          attribute(
            :a_hash,
            refrigeration_mode: :meow,
          )
        end
      end

      it "raises error on attribute declaration" do
        expect do
          value_class
        end.to raise_error(::ContractedValue::Errors::InvalidRefrigerationMode)
      end
    end
  end

  describe "attribute default value" do
    context "when with option :default_value" do
      let(:value_class) do
        # Workaround strange issue that
        # `let` cannot be used in class block
        default_val = default_value
        attr_contract = attribute_contract

        Class.new(described_class) do
          attribute(
            :attr_with_default,
            default_value: default_val,
            contract: attr_contract,
          )
        end
      end

      let(:default_value) do
        1
      end

      let(:attribute_contract) do
        ::Contracts::Builtin::Any
      end

      shared_examples "attribute with default value" do
        it "returns default value when nothing provided" do
          expect(
            value_class.new.attr_with_default,
          ).to eq(default_value)
        end

        it "returns provided value when something provided" do
          [
            nil,
            :wut,
            -> {  },
          ].each do |provided_value|
            aggregate_failures do
              expect(
                value_class.new(
                  attr_with_default: provided_value,
                ).attr_with_default,
              ).to eq(provided_value)
            end
          end
        end
      end

      context "and default value provided is `nil`" do
        let(:default_value) do
          nil
        end

        it_behaves_like "attribute with default value"

        context "when default value violates contract" do
          let(:attribute_contract) do
            ::Contracts::Builtin::Not[nil]
          end

          it "does raise error on attribute declaration" do
            expect do
              value_class
            end.to raise_error(::ContractedValue::Errors::InvalidAttributeDefaultValue)
          end
        end
      end

      context "and default value provided is not `nil`" do
        let(:default_value) do
          123
        end

        it_behaves_like "attribute with default value"

        context "when default value violates contract" do
          let(:attribute_contract) do
            ::Symbol
          end

          it "does raise error on attribute declaration" do
            expect do
              value_class
            end.to raise_error(::ContractedValue::Errors::InvalidAttributeDefaultValue)
          end
        end
      end

      context "and default value provided is mutable" do

        context "as a string" do
          let(:default_value) do
            "PikaPika"
          end

          it_behaves_like "attribute with default value"

          it "returns default value as frozen" do
            expect(
              value_class.new.attr_with_default,
            ).to be_frozen
          end
        end

        context "as a hash" do
          let(:default_value) do
            {a: {b: :c}}
          end

          it_behaves_like "attribute with default value"

          it "returns default value as frozen" do
            aggregate_failures do
              val = value_class.new.attr_with_default.fetch(:a)

              expect(val).to eq({b: :c})
              expect(val).to be_frozen
            end
          end
        end

      end
    end
  end

  describe "sub-classes of a value class" do

    describe "attribute declaration" do
      let(:parent_value_class) do
        Class.new(described_class)
      end

      it_behaves_like "attribute declaration" do
        let(:value_class) do
          Class.new(parent_value_class)
        end
      end

      describe "usage of parent class attribute" do

        let(:parent_value_class) do
          Class.new(described_class).tap do |klass|
            klass.class_eval do
              # Too lazy to include parent attributes in all examples
              attribute(:attribute_1)
            end
          end
        end
        let(:child_value_class) do
          Class.new(parent_value_class)
        end

        example "does not raise error" do
          expect {
            child_value_class.new(attribute_1: "wut")
          }.to_not raise_error
        end

      end

      describe "for new attributes absent in parent class" do

        let(:parent_value_class) do
          Class.new(described_class).tap do |klass|
            klass.class_eval do
              # Too lazy to include parent attributes in all examples
              attribute(:attribute_1, default_value: nil)
              attribute(:attribute_2, default_value: nil)
            end
          end
        end

        let(:child_value_class) do
          Class.new(parent_value_class)
        end

        example "does not raise error when declaring 1 new attribute" do
          expect {
            child_value_class.class_eval do
              attribute(:attribute_3)
            end
          }.to_not raise_error
        end

        example "does not raise error when declaring N attributes with different names" do
          expect {
            child_value_class.class_eval do
              attribute(:attribute_3)
              attribute(:attribute_4)
            end
          }.to_not raise_error
        end

        example "does raise error when declaring N attributes with the same name" do
          expect {
            child_value_class.class_eval do
              attribute(:attribute_3)
              attribute(:attribute_4)
              attribute(:attribute_3)
            end
          }.to raise_error(::ContractedValue::Errors::DuplicateAttributeDeclaration)
        end

      end
    end

    describe "attribute redeclaration" do

      let(:child_value_class) do
        Class.new(parent_value_class)
      end

      describe "for existing attributes from parent class" do
        let(:parent_value_class) do
          Class.new(described_class).tap do |klass|
            klass.class_eval do
              attribute(:attribute_1)
              attribute(:attribute_2)
            end
          end
        end
        it_behaves_like "attribute declaration" do
          let(:value_class) do
            child_value_class
          end
        end
      end

      describe "for existing attributes from parent class" do

        let(:parent_value_class) do
          Class.new(described_class).tap do |klass|
            klass.class_eval do
              attribute(
                :attribute_1,
                contract:           ::String,
                refrigeration_mode: :deep,
                # `default_value` not specified on purpose
              )
            end
          end
        end

        example "does not raise error when declaring existing attribute with different contract" do
          expect {
            child_value_class.class_eval do
              attribute(
                :attribute_1,
                contract: ::Contracts::Builtin::NatPos
              )
            end
            child_value_class.new(attribute_1: "")
          }.to raise_error(::ContractedValue::Errors::InvalidAttributeValue)
        end

        example "does not raise error when declaring existing attribute with different default_value" do
          expect {
            child_value_class.class_eval do
              attribute(
                :attribute_1,
                default_value: nil,
              )
            end
            child_value_class.new
          }.to_not raise_error
        end

        example "does not raise error when declaring existing attribute with different refrigeration_mode" do
          child_value_class.class_eval do
            attribute(
              :attribute_1,
              refrigeration_mode: :none,
            )
          end
          value_object = child_value_class.new(attribute_1: String.new)
          expect(value_object).to be_frozen
          expect(value_object.attribute_1).to_not be_frozen
        end

      end

    end

  end

end
