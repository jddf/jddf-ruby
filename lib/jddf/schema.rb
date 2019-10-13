# frozen_string_literal: true

module JDDF
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

  DISCRIMINATOR_KEYWORDS = %i[
    tag
    mapping
  ].freeze

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

  Schema = Struct.new(*SCHEMA_KEYWORDS) do
    def self.from_json(hash)
      schema = Schema.new

      if hash['definitions'].is_a?(Hash)
        schema.definitions = hash['definitions'].map do |key, schema|
          [key, from_json(schema)]
        end.to_h
      end

      schema.ref = hash['ref'] if hash['ref'].is_a?(String)

      if hash['type'].is_a?(String) && TYPES.map(&:to_s).include?(hash['type'])
        schema.type = hash['type'].to_sym
      end

      schema.enum = hash['enum'].to_set if hash['enum'].is_a?(Array)

      if hash['elements'].is_a?(Hash)
        schema.elements = from_json(hash['elements'])
      end

      if hash['properties'].is_a?(Hash)
        schema.properties = hash['properties'].map do |key, schema|
          [key, from_json(schema)]
        end.to_h
      end

      if hash['optionalProperties'].is_a?(Hash)
        optional_properties = hash['optionalProperties'].map do |key, schema|
          [key, from_json(schema)]
        end.to_h

        schema.optional_properties = optional_properties
      end

      if [true, false].include?(hash['additionalProperties'])
        schema.additional_properties = hash['additionalProperties']
      end

      schema.values = from_json(hash['values']) if hash['values'].is_a?(Hash)

      if hash['discriminator'].is_a?(Hash)
        schema.discriminator = Discriminator.from_json(hash['discriminator'])
      end

      schema
    end
  end

  Discriminator = Struct.new(*DISCRIMINATOR_KEYWORDS) do
    def self.from_json(hash)
      mapping = hash['mapping'].map do |key, schema|
        [key, Schema.from_json(schema)]
      end.to_h

      Discriminator.new(hash['tag'], mapping)
    end
  end
end
