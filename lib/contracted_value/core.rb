# frozen_string_literal: true

require "contracts"
require "ice_nine"

module ContractedValue
  module RefrigerationMode
    module Enum
      DEEP    = :deep
      SHALLOW = :shallow
      NONE    = :none

      def self.all
        [
          DEEP,
          SHALLOW,
          NONE,
        ].freeze
      end
    end
  end

  module Errors
    class DuplicateAttributeDeclaration < ArgumentError
      def initialize(key)
        super("Attribute :#{key} has already been declared")
      end
    end

    class InvalidRefrigerationMode < ArgumentError
      def initialize(val)
        valid_values = RefrigerationMode::Enum.all

        super(<<~MSG)
          option `refrigeration_mode` received <#{val.inspect}> but expected:
          #{valid_values.to_a.map(&:inspect).join(", ")}
        MSG
      end
    end

    class InvalidInputType < ArgumentError
      def initialize(input_val)
        super(
          <<~MSG
            Input must be a Hash, but got: <#{input_val.inspect}>
          MSG
        )
      end
    end

    class MissingAttributeInput < ArgumentError
      def initialize(key)
        super(
          <<~MSG
            Attribute :#{key} missing from input
          MSG
        )
      end
    end

    class InvalidAttributeValue < ArgumentError
      def initialize(key, val)
        super(
          <<~MSG
            Attribute :#{key} received invalid value:
            #{val.inspect}
          MSG
        )
      end
    end

    class InvalidAttributeDefaultValue < ArgumentError
      def initialize(key, val)
        super(
          <<~MSG
            Attribute :#{key} is declared with invalid default value:
            #{val.inspect}
          MSG
        )
      end
    end
  end

  module Private
    # No 2 procs are ever the same
    ATTR_DEFAULT_VALUE_ABSENT_VAL = -> {}
  end
  private_constant :Private

  class AttributeSet
    def self.new(*)
      ::IceNine.deep_freeze(super)
    end

    def initialize(attributes_hash = {})
      @attributes_hash = attributes_hash
    end

    def merge(other_attr_set)
      self.class.new(attributes_hash.merge(other_attr_set.attributes_hash))
    end

    def add(attr)
      merge!(self.class.new(attr.name => attr))
    end

    def each_attribute
      return to_enum(:each_attribute) unless block_given?

      attributes_hash.each_value do |v|
        yield(v)
      end
    end

    protected

    def merge!(other_attr_set)
      shared_keys = attr_names & other_attr_set.attr_names
      if shared_keys.any?
        raise(Errors::DuplicateAttributeDeclaration, shared_keys.first)
      end

      self.class.new(attributes_hash.merge(other_attr_set.attributes_hash))
    end

    def attr_names
      @attributes_hash.keys
    end

    attr_reader :attributes_hash
  end

  class Attribute
    def self.new(...)
      ::IceNine.deep_freeze(super)
    end

    def initialize(
      name:, contract:, refrigeration_mode:, default_value:
    )

      @name = name
      @contract = contract
      @refrigeration_mode = refrigeration_mode
      @default_value = default_value

      raise_error_if_inputs_invalid
    end

    attr_reader :name
    attr_reader :contract
    attr_reader :refrigeration_mode

    def extract_value(hash)
      if hash.key?(name)
        attr_value = hash.fetch(name)

        unless Contract.valid?(attr_value, contract)
          raise(
            Errors::InvalidAttributeValue.new(name, attr_value),
          )
        end

        return attr_value
      end

      # Data missing from input
      # Use default value if present
      # Raise error otherwise

      return default_value if default_value_present?

      raise(
        Errors::MissingAttributeInput.new(
          name,
        ),
      )
    end

    private

    attr_reader :default_value

    def raise_error_if_inputs_invalid
      raise_error_if_refrigeration_mode_invalid
      raise_error_if_default_value_invalid
    end

    def raise_error_if_refrigeration_mode_invalid
      return if RefrigerationMode::Enum.all.include?(refrigeration_mode)

      raise Errors::InvalidRefrigerationMode.new(
        refrigeration_mode,
      )
    end

    def raise_error_if_default_value_invalid
      return unless default_value_present?
      return if Contract.valid?(default_value, contract)

      raise(
        Errors::InvalidAttributeDefaultValue.new(
          name,
          default_value,
        ),
      )
    end

    def default_value_present?
      # The default value of default value (ATTR_DEFAULT_VALUE_ABSENT_VAL)
      # only represents the absence of default value
      default_value != Private::ATTR_DEFAULT_VALUE_ABSENT_VAL
    end
  end

  class Value
    # rubocop:disable Metrics/CyclomaticComplexity
    # rubocop:disable Metrics/AbcSize
    def initialize(input_attr_values = {})
      input_attr_values_hash =
        case input_attr_values
        when ::Hash
          input_attr_values
        when Value
          input_attr_values.to_h
        else
          raise(
            Errors::InvalidInputType.new(
              input_attr_values,
            ),
          )
        end

      self.class.send(:attribute_set).each_attribute do |attribute|
        attr_value = attribute.extract_value(input_attr_values_hash)

        sometimes_frozen_attr_value =
          case attribute.refrigeration_mode
          when RefrigerationMode::Enum::DEEP
            # Use ice_nine for deep freezing
            ::IceNine.deep_freeze(attr_value)
          when RefrigerationMode::Enum::SHALLOW
            # No need to re-freeze
            attr_value.frozen? ? attr_value : attr_value.freeze
          when RefrigerationMode::Enum::NONE
            # No freezing
            attr_value
          else
            raise Errors::InvalidRefrigerationMode.new(
              refrigeration_mode,
            )
          end

        # Using symbol since attribute names are limited in number
        # An alternative would be using frozen string
        instance_variable_set(
          :"@#{attribute.name}",
          sometimes_frozen_attr_value,
        )
      end

      freeze
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/CyclomaticComplexity

    def to_h
      self.class.send(:attribute_set).
        each_attribute.each_with_object({}) do |attribute, hash|
          hash[attribute.name] = instance_variable_get(:"@#{attribute.name}")
        end
    end

    # == Class interface == #
    class << self
      def inherited(klass)
        super

        klass.instance_variable_set(:@attribute_set, AttributeSet.new)
      end

      private

      # @api
      def attribute(
        name,
        contract: ::Contracts::Builtin::Any,
        refrigeration_mode: RefrigerationMode::Enum::DEEP,
        default_value: Private::ATTR_DEFAULT_VALUE_ABSENT_VAL
      )

        attr = Attribute.new(
          name: name,
          contract: contract,
          refrigeration_mode: refrigeration_mode,
          default_value: default_value,
        )
        @attribute_set = @attribute_set.add(attr)

        attr_reader(name)
      end

      # @api private
      def super_attribute_set
        unless superclass.respond_to?(:attribute_set, true)
          return AttributeSet.new
        end

        superclass.send(:attribute_set)
      end

      # @api private
      def attribute_set
        # When the chain comes back to original class
        # (ContractedValue::Value)
        # @attribute_set would be nil
        super_attribute_set.merge(@attribute_set || AttributeSet.new)
      end
    end
    # == Class interface == #
  end
end
