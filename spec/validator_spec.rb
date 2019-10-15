# frozen_string_literal: true

describe 'JDDF' do
  describe 'Validator' do
    describe 'validate' do
      describe 'spec tests' do
        Dir['jddf-spec/tests/validation/*'].each do |path|
          describe path do
            suites = JSON.parse(File.read(path))
            suites.each do |suite, index|
              describe suite['name'] do
                suite['instances'].each_with_index do |test_case, index|
                  it index do
                    schema = JDDF::Schema.from_json(suite['schema'])
                    validator = JDDF::Validator.new

                    expected = test_case['errors'].map do |error|
                      err = JDDF::ValidationError.new
                      err.instance_path = error['instancePath'].split('/')[1..] || []
                      err.schema_path = error['schemaPath'].split('/')[1..] || []

                      err
                    end

                    actual = validator.validate(schema, test_case['instance'])
                    expect(actual.sort_by(&:instance_path)).to eq expected.sort_by(&:instance_path)
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
