require_relative 'helper'

describe 'CfnFlow' do
  subject { CfnFlow }

  describe '.config_path' do
    it 'should be ./cfn-flow.yml by default' do
      ENV.delete('CFN_FLOW_CONFIG_PATH')
      subject.config_path.must_equal 'cfn-flow.yml'
    end

    it 'can be overridden with ENV[CFN_FLOW_CONFIG_PATH]' do
      ENV['CFN_FLOW_CONFIG_PATH'] = 'foo/bar'
      subject.config_path.must_equal 'foo/bar'
    end
  end

  describe '.config_loaded?' do
    it 'should be false by default' do
      subject.config_loaded?.must_equal false
    end

    it 'should be true after loading' do
      subject.load_config
      subject.config_loaded?.must_equal true
    end
  end

  describe '.config' do
    it('should be a hash') { subject.config.must_be_kind_of(Hash) }
  end

  describe '.service' do
    it('raises an error when missing') do
      subject.instance_variable_set(:@config, {})
      error = -> { subject.service }.must_raise(Thor::Error)
      error.message.must_match 'No service name'
    end

    it('returns the service') do
      subject.instance_variable_set(:@config, {'service' => 'RoflScaler'})
      subject.service.must_equal 'RoflScaler'
    end
  end

  describe '.stack_params' do
    it('raises an error when missing') do
      subject.instance_variable_set(:@config, {})
      error = -> { subject.stack_params('env') }.must_raise(Thor::Error)
      error.message.must_match 'No stack defined'
    end

    it('expands parameters') do
      stack = {'parameters' => {'ami' => 'ami-12345' } }
      subject.instance_variable_set(:@config, {'service' => 'myservice', 'stack' => stack})
      subject.stack_params('env')[:parameters].must_equal [ { parameter_key: 'ami', parameter_value: 'ami-12345' } ]
    end

    it('fetches stack outputs for parameters with an explicit output') do
      output_value = 'my-output-value'
      Aws.config[:cloudformation]= {
        stub_responses: {
          describe_stacks: { stacks: [ stub_stack_data.merge(outputs: [{ output_key: "myoutput", output_value: output_value } ]) ] }
        }
      }

      stack = {'parameters' => {'output_param' => {'Stack' => 'other-stack', 'Output' => "myoutput"}}}
      subject.instance_variable_set(:@config, {'service' => 'myservice', 'stack' => stack})
      subject.stack_params('env')[:parameters].must_equal [ { parameter_key: 'output_param', parameter_value: 'my-output-value' } ]
    end

    it('fetches stack outputs for parameters with an implied output') do
      output_value = 'my-output-value'
      Aws.config[:cloudformation]= {
        stub_responses: {
          describe_stacks: { stacks: [ stub_stack_data.merge(outputs: [{ output_key: "myoutput", output_value: output_value } ]) ] }
        }
      }

      stack = {'parameters' => {'myoutput' => {'Stack' => 'other-stack'}}}
      subject.instance_variable_set(:@config, {'service' => 'myservice', 'stack' => stack})
      subject.stack_params('env')[:parameters].must_equal [ { parameter_key: 'myoutput', parameter_value: 'my-output-value' } ]
    end



    it('expands tags') do
      stack = {'tags' => {'Deployer' => 'Aaron' } }
      subject.instance_variable_set(:@config, {'service' => 'myservice', 'stack' => stack})
      expected = [
        { key: 'Deployer', value: 'Aaron' },
        { key: 'CfnFlowService', value: 'myservice' },
        { key: 'CfnFlowEnvironment', value: 'env' }
      ]

      subject.stack_params('env')[:tags].must_equal expected
    end

    it 'appends CfnFlow tags' do
      subject.instance_variable_set(:@config, {'service' => 'myservice', 'stack' => {}})
      expected = [
        { key: 'CfnFlowService', value: 'myservice' },
        { key: 'CfnFlowEnvironment', value: 'env' }
      ]

      subject.stack_params('env')[:tags].must_equal expected
    end

    it 'expands template body' do
      template_path = 'spec/data/sqs.template'
      stack = {'template_body' => template_path}
      subject.instance_variable_set(:@config, {'service' => 'myservice', 'stack' => stack})
      subject.stack_params('env')[:template_body].must_equal CfnFlow::Template.new(template_path).to_json
    end

  end

  describe '.template_s3_bucket' do
    it('raises an error when missing') do
      subject.instance_variable_set(:@config, {})
      error = -> { subject.template_s3_bucket }.must_raise(Thor::Error)
      error.message.must_match 'No s3_bucket defined'

      subject.instance_variable_set(:@config, {'templates' => {}})
      error = -> { subject.template_s3_bucket }.must_raise(Thor::Error)
      error.message.must_match 'No s3_bucket defined'
    end

    it 'succeeds' do
      subject.instance_variable_set(:@config, {'templates' => {'s3_bucket' => 'hello'}})
      subject.template_s3_bucket.must_equal 'hello'
    end
  end

  describe '.template_s3_prefix' do
    it('raises an error when missing') do
      subject.instance_variable_set(:@config, {})
      error = -> { subject.template_s3_prefix }.must_raise(Thor::Error)
      error.message.must_match 'No templates defined'
    end

    it 'succeeds' do
      subject.instance_variable_set(:@config, {'templates' => {'s3_prefix' => 'hello'}})
      subject.template_s3_prefix.must_equal 'hello'
    end

    it 'can be nil' do
      subject.instance_variable_set(:@config, {'templates' => {}})
      subject.template_s3_prefix.must_equal nil
    end
  end

  describe '.cfn_client' do
    it 'should work' do
      subject.cfn_client.must_be_kind_of Aws::CloudFormation::Client
    end

    describe 'aws region' do
      it 'should default to the env region' do
        ENV['AWS_REGION'] = 'env-region'
        subject.cfn_client.config.region.must_equal 'env-region'
      end

      it 'can be overridden with config' do
        ENV['AWS_REGION'] = 'env-region'
        subject.instance_variable_set(:@config, {'region' => 'config-region' })
        subject.cfn_client.config.region.must_equal 'config-region'
      end
    end

  end

  describe '.cfn_resource' do
    it 'should work' do
      subject.cfn_resource.must_be_kind_of Aws::CloudFormation::Resource
    end

    it 'should set a retry_limit' do
      subject.cfn_resource.client.config.retry_limit.must_equal 10
    end

    describe 'aws region' do
      it 'should default to the env region' do
        ENV['AWS_REGION'] = 'env-region'
        subject.cfn_client.config.region.must_equal 'env-region'
      end

      it 'can be overridden with config' do
        ENV['AWS_REGION'] = 'env-region'
        subject.instance_variable_set(:@config, {'region' => 'config-region' })
        subject.cfn_client.config.region.must_equal 'config-region'
      end
    end
  end

  describe '.exit_on_failure?' do
    it 'is true by default' do
      CfnFlow.remove_instance_variable(:@exit_on_failure) if CfnFlow.instance_variable_defined?(:@exit_on_failure)
      CfnFlow.exit_on_failure?.must_equal true
    end

    it 'can be set' do
      CfnFlow.exit_on_failure = false
      CfnFlow.exit_on_failure?.must_equal false
    end
  end
end
