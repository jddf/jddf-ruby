# frozen_string_literal: true

require 'json'
require 'set'

describe 'JDDF' do
  describe 'JDDF::Schema' do
    describe 'JDDF::Schema::from_json' do
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
    end
  end
end
