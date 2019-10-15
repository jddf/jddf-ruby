# frozen_string_literal: true

require 'time'

module JDDF
  ValidationError = Struct.new(:instance_path, :schema_path)

  # Validator
  class Validator
    attr_accessor :max_depth
    attr_accessor :max_errors

    def validate(schema, instance)
      vm = VM.new
      vm.max_depth = max_depth
      vm.max_errors = max_errors
      vm.root_schema = schema
      vm.instance_tokens = []
      vm.schema_tokens = [[]]
      vm.errors = []

      vm.validate(schema, instance)

      vm.errors
    end

    class VM
      attr_accessor :max_depth
      attr_accessor :max_errors
      attr_accessor :root_schema
      attr_accessor :instance_tokens
      attr_accessor :schema_tokens
      attr_accessor :errors

      def validate(schema, instance, parent_tag = nil)
        case schema.form
        when :ref
          schema_tokens << ['definitions', schema.ref]
          validate(root_schema.definitions[schema.ref], instance)
          schema_tokens.pop
        when :type
          push_schema_token('type')

          case schema.type
          when :boolean
            push_error if instance != true && instance != false
          when :float32, :float64
            push_error unless instance.is_a?(Numeric)
          when :int8
            validate_int(instance, -128, 127)
          when :uint8
            validate_int(instance, 0, 255)
          when :int16
            validate_int(instance, -32768, 32767)
          when :uint16
            validate_int(instance, 0, 65535)
          when :int32
            validate_int(instance, -2147483648, 2147483647)
          when :uint32
            validate_int(instance, 0, 4294967295)
          when :string
            push_error unless instance.is_a?(String)
          when :timestamp
            begin
              DateTime.rfc3339(instance)
            rescue TypeError, ArgumentError
              push_error
            end
          end

          pop_schema_token
        when :enum
          push_schema_token('enum')
          push_error unless schema.enum.include?(instance)
          pop_schema_token
        when :elements
          push_schema_token('elements')

          if instance.is_a?(Array)
            instance.each_with_index do |sub_instance, index|
              push_instance_token(index.to_s)
              validate(schema.elements, sub_instance)
              pop_instance_token
            end
          else
            push_error
          end

          pop_schema_token
        when :properties
          if instance.is_a?(Hash)
            if schema.properties
              push_schema_token('properties')

              schema.properties.each do |key, sub_schema|
                push_schema_token(key)

                if instance.include?(key)
                  push_instance_token(key)
                  validate(sub_schema, instance[key])
                  pop_instance_token
                else
                  push_error
                end

                pop_schema_token
              end

              pop_schema_token
            end

            if schema.optional_properties
              push_schema_token('optionalProperties')

              schema.optional_properties.each do |key, sub_schema|
                push_schema_token(key)

                if instance.include?(key)
                  push_instance_token(key)
                  validate(sub_schema, instance[key])
                  pop_instance_token
                end

                pop_schema_token
              end

              pop_schema_token
            end

            unless schema.additional_properties
              instance.keys.each do |key|
                in_properties = schema.properties && schema.properties.include?(key)
                in_optional_properties = schema.optional_properties && schema.optional_properties.include?(key)
                is_parent_tag = parent_tag == key

                unless in_properties || in_optional_properties || is_parent_tag
                  push_instance_token(key)
                  push_error
                  pop_instance_token
                end
              end
            end
          else
            if schema.properties.nil?
              push_schema_token('optionalProperties')
            else
              push_schema_token('properties')
            end

            push_error
            pop_schema_token
          end
        when :values
          push_schema_token('values')

          if instance.is_a?(Hash)
            instance.each do |key, value|
              push_instance_token(key)
              validate(schema.values, value)
              pop_instance_token
            end
          else
            push_error
          end

          pop_schema_token
        when :discriminator
          push_schema_token('discriminator')

          if instance.is_a?(Hash)
            if instance.include?(schema.discriminator.tag)
              tag_value = instance[schema.discriminator.tag]

              if tag_value.is_a?(String)
                push_schema_token('mapping')

                if schema.discriminator.mapping.include?(tag_value)
                  push_schema_token(tag_value)
                  validate(schema.discriminator.mapping[tag_value], instance, schema.discriminator.tag)
                  pop_schema_token
                else
                  push_instance_token(schema.discriminator.tag)
                  push_error
                  pop_instance_token
                end

                pop_schema_token
              else
                push_instance_token(schema.discriminator.tag)
                push_schema_token('tag')
                push_error
                pop_schema_token
                pop_instance_token
              end
            else
              push_schema_token('tag')
              push_error
              pop_schema_token
            end
          else
            push_error
          end

          pop_schema_token
        end
      end

      def validate_int(instance, min, max)
        if instance.is_a?(Numeric)
          if instance.modulo(1).nonzero? || instance < min || instance > max
            push_error
          end
        else
          push_error
        end
      end

      def push_instance_token(token)
        instance_tokens << token
      end

      def pop_instance_token
        instance_tokens.pop
      end

      def push_schema_token(token)
        schema_tokens.last << token
      end

      def pop_schema_token
        schema_tokens.last.pop
      end

      def push_error
        error = ValidationError.new
        error.instance_path = instance_tokens.clone
        error.schema_path = schema_tokens.last.clone

        errors << error
      end
    end
  end
end
