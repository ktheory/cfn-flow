require_relative '../helper'

describe 'CfnFlow::StackParams' do
  subject { CfnFlow::StackParams }

  it 'should be a hash' do
    subject.new.must_be_kind_of Hash
  end

  describe '.expand' do
    it "todo"
  end

  describe '.symbolized_keys' do
    it 'works' do
      subject[{'foo' => 1, :bar => true}].symbolized_keys.must_equal({foo: 1, bar: true})
    end
  end

  describe 'expand_parameters' do
    it 'reformats parameters hash to array of hashes' do
      hash = {
        parameters: { 'k1' => 'v1', 'k2' => 'v2' }
      }

      expected = {
        parameters: [
          {parameter_key: 'k1', parameter_value: 'v1'},
          {parameter_key: 'k2', parameter_value: 'v2'}
        ]
      }

      subject[hash].expand_parameters.must_equal expected
    end

    it 'fetches stack outputs with explicit output key' do
      cached_stack = MiniTest::Mock.new
      cached_stack.expect(:get_output, 'my-output-value', [{stack: 'my-stack', output: 'my-output-key'}])
      hash = {
        parameters: { 'my-key' => { 'stack' => 'my-stack', 'output' => 'my-output-key'}}
      }

      expected = {
        parameters: [ {parameter_key: 'my-key', parameter_value: 'my-output-value'} ]
      }

      subject[hash].expand_parameters(cached_stack: cached_stack).must_equal expected
      cached_stack.verify
    end

    it 'fetches stack outputs with implicit output key' do
      cached_stack = MiniTest::Mock.new
      cached_stack.expect(:get_output, 'my-output-value', [{stack: 'my-stack', output: 'my-key'}])
      hash = {
        parameters: { 'my-key' => { 'stack' => 'my-stack'}}
      }

      expected = {
        parameters: [ {parameter_key: 'my-key', parameter_value: 'my-output-value'} ]
      }

      subject[hash].expand_parameters(cached_stack: cached_stack).must_equal expected
      cached_stack.verify
    end
  end

  describe '.expand_tags' do
    it 'expands tags hash to array of hashes' do
      hash = {tags: {'k' => 'v'} }
      expected = {tags: [{key: 'k', value: 'v'}]}
      subject[hash].expand_tags.must_equal expected
    end
  end

  describe '.add_tag' do
    it 'sets an empty tag hash' do
      subject.new.add_tag('k' => 'v').must_equal({tags: [{key: 'k', value: 'v'}]})

    end
    it 'appends to existing tag hash' do
      orig = subject[{tags: [{key: 'k1', value: 'v1'}] }]
      expected = {tags: [{key: 'k1', value: 'v1'}, {key: 'k2', value: 'v2'}] }

      orig.add_tag('k2' => 'v2').must_equal expected

    end
  end

  describe '.expand_template_body' do
    it 'expands template body' do
      templater = MiniTest::Mock.new
      template_object = MiniTest::Mock.new
      template_path = 'spec/data/sqs.template'


      # NB: undef to_json b/c of this issue http://git.io/vWFV6
      template_object.send(:undef_method, :to_json)
      template_object.expect(:to_json, 'json')

      templater.expect(:new, template_object, [template_path])
      template_path = 'spec/data/sqs.template'

      result = subject[template_body: template_path].expand_template_body(templater: templater)

      templater.verify
      template_object.verify
      result.must_equal({template_body: 'json'})
    end
  end


end
