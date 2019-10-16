# frozen_string_literal: true

require 'json'
require 'set'

describe 'JDDF' do
  describe 'Schema' do
    describe 'from_json' do
      it 'parses from JSON' do
        input = %(
          {
            "definitions": {"x": {}},
            "ref": "x",
            "type": "uint32",
            "enum": ["FOO", "BAR"],
            "elements": {},
            "properties": {"x": {}},
            "optionalProperties": {"x": {}},
            "additionalProperties": true,
            "values": {},
            "discriminator": {
              "tag": "x",
              "mapping": {"x": {}}
            }
          }
        )

        expected = JDDF::Schema.new(
          {
            'x' => JDDF::Schema.new
          },
          'x',
          :uint32,
          Set['FOO', 'BAR'],
          JDDF::Schema.new,
          {
            'x' => JDDF::Schema.new
          },
          {
            'x' => JDDF::Schema.new
          },
          true,
          JDDF::Schema.new,
          JDDF::Discriminator.new('x', 'x' => JDDF::Schema.new)
        )

        actual = JDDF::Schema.from_json(JSON.parse(input))
        expect(actual).to eq expected
      end

      describe 'spec tests' do
        test_cases = File.read('jddf-spec/tests/invalid-schemas.json')
        test_cases = JSON.parse(test_cases)
        test_cases.each do |test_case|
          it test_case['name'] do
            errored = false

            begin
              JDDF::Schema.from_json(test_case['schema']).verify
            rescue ArgumentError, TypeError
              errored = true
            end

            expect(errored).to be true
          end
        end
      end
    end
  end
end
