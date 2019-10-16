# frozen_string_literal: true

describe 'JDDF' do
  describe 'Validator' do
    describe 'validate' do
      it 'supports max depth' do
        validator = JDDF::Validator.new
        validator.max_depth = 3

        schema = JDDF::Schema.from_json(
          'definitions' => { '' => { 'ref' => '' } },
          'ref' => ''
        )

        expect do
          validator.validate(schema, nil)
        end.to raise_error JDDF::MaxDepthExceededError
      end

      it 'supports max errors' do
        validator = JDDF::Validator.new
        validator.max_errors = 3

        schema = JDDF::Schema.from_json(
          'elements' => { 'type' => 'string' }
        )

        errors = validator.validate(schema, [nil, nil, nil, nil, nil])
        expect(errors.size).to eq 3
      end

      describe 'spec tests' do
        Dir['jddf-spec/tests/validation/*'].each do |path|
          describe path do
            suites = JSON.parse(File.read(path))
            suites.each do |suite|
              describe suite['name'] do
                suite['instances'].each_with_index do |test_case, index|
                  it index do
                    schema = JDDF::Schema.from_json(suite['schema']).verify
                    validator = JDDF::Validator.new

                    expected = test_case['errors'].map do |error|
                      instance_path = error['instancePath'].split('/').drop(1)
                      schema_path = error['schemaPath'].split('/').drop(1)

                      err = JDDF::ValidationError.new
                      err.instance_path = instance_path || []
                      err.schema_path = schema_path || []
                      err
                    end

                    actual = validator.validate(schema, test_case['instance'])

                    expected.sort_by!(&:instance_path)
                    actual.sort_by!(&:instance_path)

                    expect(actual).to eq expected
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
