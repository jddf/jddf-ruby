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
      if !hash.is_a?(Hash)
        raise TypeError.new('hash must be a Hash')
      end

      schema = Schema.new

      if hash.include?('definitions')
        if hash['definitions'].is_a?(Hash)
          schema.definitions = hash['definitions'].map do |key, schema|
            [key, from_json(schema)]
          end.to_h
        else
          raise TypeError.new('definitions not Hash')
        end
      end

      if hash.include?('ref')
        if hash['ref'].is_a?(String)
          schema.ref = hash['ref']
        else
          raise TypeError.new('ref not String')
        end
      end

      if hash.include?('type')
        if hash['type'].is_a?(String) && TYPES.map(&:to_s).include?(hash['type'])
          schema.type = hash['type'].to_sym
        else
          raise TypeError.new("type not one of #{TYPES.inspect}")
        end
      end

      if hash.include?('enum')
        if hash['enum'].is_a?(Array)
          if hash['enum'].empty?
            raise ArgumentError.new('enum is empty array')
          end

          hash['enum'].each do |value|
            if !value.is_a?(String)
              raise TypeError.new('enum element not String')
            end
          end

          schema.enum = hash['enum'].to_set

          if schema.enum.size != hash['enum'].size
            raise ArgumentError.new('enum contains duplicates')
          end
        else
          raise TypeError.new('enum not Array')
        end
      end

      if hash.include?('elements')
        if hash['elements'].is_a?(Hash)
          schema.elements = from_json(hash['elements'])
        else
          raise TypeError.new('elements not Hash')
        end
      end

      if hash.include?('properties')
        if hash['properties'].is_a?(Hash)
          schema.properties = hash['properties'].map do |key, schema|
            [key, from_json(schema)]
          end.to_h
        else
          raise TypeError.new('properties not Hash')
        end
      end

      if hash.include?('optionalProperties')
        if hash['optionalProperties'].is_a?(Hash)
          optional_properties = hash['optionalProperties'].map do |key, schema|
            [key, from_json(schema)]
          end.to_h

          schema.optional_properties = optional_properties
        else
          raise TypeError.new('optionalProperties not Hash')
        end
      end

      if hash.include?('additionalProperties')
        if [true, false].include?(hash['additionalProperties'])
          schema.additional_properties = hash['additionalProperties']
        else
          raise TypeError.new('additionalProperties not boolean')
        end
      end

      if hash.include?('values')
        if hash['values'].is_a?(Hash)
          schema.values = from_json(hash['values'])
        else
          raise TypeError.new('values not Hash')
        end
      end

      if hash.include?('discriminator')
        if hash['discriminator'].is_a?(Hash)
          schema.discriminator = Discriminator.from_json(hash['discriminator'])
        else
          raise TypeError.new('discriminator not Hash')
        end
      end

      schema
    end

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

    def verify(root = self)
      empty = true

      if ref
        empty = false

        unless root.definitions&.keys&.include?(ref)
          raise ArgumentError.new('reference to non-existent definition')
        end
      end

      if type
        raise ArgumentError.new('invalid form') unless empty
        empty = false
      end

      if enum
        raise ArgumentError.new('invalid form') unless empty
        empty = false
      end

      if elements
        raise ArgumentError.new('invalid form') unless empty
        empty = false

        elements.verify(root)
      end

      if properties || optional_properties
        raise ArgumentError.new('invalid form') unless empty
        empty = false

        properties&.values&.each { |schema| schema.verify(root) }
        optional_properties&.values&.each { |schema| schema.verify(root) }
      end

      if values
        raise ArgumentError.new('invalid form') unless empty
        empty = false

        values.verify(root)
      end

      if properties && optional_properties
        unless (properties.keys & optional_properties.keys).empty?
          raise ArgumentError.new('properties and optional_properties share key')
        end
      end

      if discriminator
        raise ArgumentError.new('invalid form') unless empty
        empty = false

        discriminator.mapping.values.each do |schema|
          schema.verify(root)

          if schema.form == :properties
            in_props = schema&.properties&.include?(discriminator.tag)
            in_opt_props = schema&.optional_properties&.include?(discriminator.tag)
            if in_props || in_opt_props
              raise ArgumentError.new('tag appears in mapping properties')
            end
          else
            raise ArgumentError.new('mapping value not of properties form')
          end
        end
      end

      self
    end
  end

  Discriminator = Struct.new(*DISCRIMINATOR_KEYWORDS) do
    def self.from_json(hash)
      raise TypeError.new('tag not String') unless hash['tag'].is_a?(String)
      raise TypeError.new('mapping not Hash') unless hash['mapping'].is_a?(Hash)

      mapping = hash['mapping'].map do |key, schema|
        [key, Schema.from_json(schema)]
      end.to_h

      Discriminator.new(hash['tag'], mapping)
    end
  end
end
