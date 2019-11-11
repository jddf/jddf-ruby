# frozen_string_literal: true

module JDDF
  # The keywords that may appear on a JDDF schema.
  #
  # Each of these values correspond to an attribute available on {Schema}.
  SCHEMA_KEYWORDS = %i[
    definitions
    ref
    type
    enum
    elements
    properties
    optional_properties
    additional_properties
    values
    discriminator
  ].freeze

  # The keywords that may appear on a JDDF schema discriminator object.
  #
  # Each of these values correspond to an attribute available on
  # {Discriminator}.
  DISCRIMINATOR_KEYWORDS = %i[
    tag
    mapping
  ].freeze

  # The values the +type+ keyword may take on in a JDDF schema.
  #
  # The +type+ attribute of {Schema} has one of these values.
  TYPES = %i[
    boolean
    int8
    uint8
    int16
    uint16
    int32
    uint32
    float32
    float64
    string
    timestamp
  ].freeze

  # A JDDF schema.
  #
  # This class is a +Struct+. Validate instances against it using
  # {Validator#validate}.
  #
  # This class's attributes are in {SCHEMA_KEYWORDS}.
  Schema = Struct.new(*SCHEMA_KEYWORDS) do
    # Construct a {Schema} from parsed JSON.
    #
    # This function performs type checks to ensure the data is well-typed, but
    # does not perform all the checks necesary to ensure data is a correct JDDF
    # schema. Using this function in combination with {verify} ensures that a
    # JDDF schema is guaranteed to be correct according to the spec.
    #
    # +hash+ should be the result of calling +JSON#parse+.
    #
    # @param hash [Hash] a JSON object representing a JDDF schema
    #
    # @raise [ArgumentError, TypeError] if the inputted hash is not a valid
    #   schema
    #
    # @return [Schema] the parsed schema
    def self.from_json(hash)
      raise TypeError.new, 'hash must be a Hash' unless hash.is_a?(Hash)

      schema = Schema.new

      if hash.include?('definitions')
        unless hash['definitions'].is_a?(Hash)
          raise TypeError, 'definitions not Hash'
        end

        schema.definitions = hash['definitions'].map do |key, schema|
          [key, from_json(schema)]
        end.to_h
      end

      if hash.include?('ref')
        raise TypeError, 'ref not String' unless hash['ref'].is_a?(String)

        schema.ref = hash['ref']
      end

      if hash.include?('type')
        raise TypeError, 'type not String' unless hash['type'].is_a?(String)

        unless TYPES.map(&:to_s).include?(hash['type'])
          raise TypeError, "type not in #{TYPES}"
        end

        schema.type = hash['type'].to_sym
      end

      if hash.include?('enum')
        raise TypeError, 'enum not Array' unless hash['enum'].is_a?(Array)
        raise ArgumentError, 'enum is empty array' if hash['enum'].empty?

        hash['enum'].each do |value|
          raise TypeError, 'enum element not String' unless value.is_a?(String)
        end

        schema.enum = hash['enum'].to_set

        if schema.enum.size != hash['enum'].size
          raise ArgumentError, 'enum contains duplicates'
        end
      end

      if hash.include?('elements')
        raise TypeError, 'elements not Hash' unless hash['elements'].is_a?(Hash)

        schema.elements = from_json(hash['elements'])
      end

      if hash.include?('properties')
        unless hash['properties'].is_a?(Hash)
          raise TypeError, 'properties not Hash'
        end

        schema.properties = hash['properties'].map do |key, schema|
          [key, from_json(schema)]
        end.to_h
      end

      if hash.include?('optionalProperties')
        unless hash['optionalProperties'].is_a?(Hash)
          raise TypeError, 'optionalProperties not Hash'
        end

        optional_properties = hash['optionalProperties'].map do |key, schema|
          [key, from_json(schema)]
        end.to_h

        schema.optional_properties = optional_properties
      end

      if hash.include?('additionalProperties')
        unless [true, false].include?(hash['additionalProperties'])
          raise TypeError, 'additionalProperties not boolean'
        end

        schema.additional_properties = hash['additionalProperties']
      end

      if hash.include?('values')
        raise TypeError, 'values not Hash' unless hash['values'].is_a?(Hash)

        schema.values = from_json(hash['values'])
      end

      if hash.include?('discriminator')
        unless hash['discriminator'].is_a?(Hash)
          raise TypeError, 'discriminator not Hash'
        end

        schema.discriminator = Discriminator.from_json(hash['discriminator'])
      end

      schema
    end

    # Determine which of the eight forms this schema takes on.
    #
    # This function is well-defined only if the schema is a correct schema --
    # i.e., you have called {verify} and no errors were raised.
    #
    # @return [Symbol] the form of the schema
    def form
      return :ref if ref
      return :type if type
      return :enum if enum
      return :elements if elements
      return :properties if properties || optional_properties
      return :values if values
      return :discriminator if discriminator

      :empty
    end

    # Check that the schema represents a correct JDDF schema.
    #
    # To make it convenient to construct and verify a schema, this function
    # returns +self+ if the schema is correct.
    #
    # @raise [ArgumentError] if the schema is incorrect
    #
    # @return [Schema] self
    def verify(root = self, is_root = true)
      if definitions
        raise ArgumentError, 'non-root definitions' unless is_root
        definitions.values.each { |schema| schema.verify(root, false) }
      end

      empty = true

      if ref
        empty = false

        unless root.definitions&.keys&.include?(ref)
          raise ArgumentError, 'reference to non-existent definition'
        end
      end

      if type
        raise ArgumentError, 'invalid form' unless empty

        empty = false
      end

      if enum
        raise ArgumentError, 'invalid form' unless empty

        empty = false
      end

      if elements
        raise ArgumentError, 'invalid form' unless empty

        empty = false

        elements.verify(root, false)
      end

      if properties || optional_properties
        raise ArgumentError, 'invalid form' unless empty

        empty = false

        properties&.values&.each { |schema| schema.verify(root, false) }
        optional_properties&.values&.each { |schema| schema.verify(root, false) }
      end

      if values
        raise ArgumentError, 'invalid form' unless empty

        empty = false

        values.verify(root, false)
      end

      if properties && optional_properties
        unless (properties.keys & optional_properties.keys).empty?
          raise ArgumentError, 'properties and optional_properties share key'
        end
      end

      if discriminator
        raise ArgumentError, 'invalid form' unless empty

        discriminator.mapping.values.each do |schema|
          schema.verify(root, false)

          unless schema.form == :properties
            raise ArgumentError, 'mapping value not of properties form'
          end

          if schema&.properties&.include?(discriminator.tag) ||
             schema&.optional_properties&.include?(discriminator.tag)
            raise ArgumentError, 'tag appears in mapping properties'
          end
        end
      end

      self
    end
  end

  # A JDDF schema discriminator object.
  #
  # This class is a +Struct+. It is primarily a helper sub-structure of
  # {Schema}.
  #
  # The attributes of this struct are in {DISCRIMINATOR_KEYWORDS}.
  Discriminator = Struct.new(*DISCRIMINATOR_KEYWORDS) do
    # Construct a {Discriminator} from parsed JSON.
    #
    # This is primarily meant to be a helper method to {Schema#from_json}.
    def self.from_json(hash)
      raise TypeError, 'tag not String' unless hash['tag'].is_a?(String)
      raise TypeError, 'mapping not Hash' unless hash['mapping'].is_a?(Hash)

      mapping = hash['mapping'].map do |key, schema|
        [key, Schema.from_json(schema)]
      end.to_h

      Discriminator.new(hash['tag'], mapping)
    end
  end
end
