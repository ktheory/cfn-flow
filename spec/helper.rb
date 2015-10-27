require "rubygems"
require "bundler/setup"
require "minitest/autorun"
require "minitest/pride"

begin
  require 'pry'
rescue LoadError
  # NBD.
end

require "cfn-flow"

Aws.config[:stub_responses] = true
ENV['AWS_REGION'] = 'us-east-1'
ENV['AWS_ACCESS_KEY_ID'] = 'test-key'
ENV['AWS_SECRET_ACCESS_KEY'] = 'test-secret'
ENV['CFN_FLOW_DEV_NAME'] = 'cfn-flow-specs'
ENV['CFN_FLOW_CONFIG_PATH'] = 'spec/data/cfn-flow.yml'
ENV['CFN_FLOW_EVENT_POLL_INTERVAL'] = '0'

class Minitest::Spec
  before do
    # Reset env between tests:
    @orig_env = ENV.to_hash

    # Disable exit on failure so CLI tests don't bomb out
    CfnFlow.exit_on_failure = false
  end

  after do
    # Reset env
    ENV.clear
    ENV.update(@orig_env)

    # Reset stubs
    CfnFlow.clear!
    Aws.config.delete(:cloudformation)
  end

  def memo_now
    @now = Time.now
  end

  def stub_stack_data(attrs = {})
    {
      stack_name: "mystack",
      stack_status: 'CREATE_COMPLETE',
      creation_time: memo_now,
      tags: [
        {key: 'CfnFlowService', value: CfnFlow.service},
        {key: 'CfnFlowEnvironment', value: 'production'}
      ],
      outputs: [
        { output_key: "myoutput", output_value: 'myvalue' }
      ]
    }.merge(attrs)
  end

  def stub_event_data(attrs = {})
    {
      stack_id: 'mystack',
      stack_name: 'mystack',
      event_id: SecureRandom.hex,
      resource_status: 'CREATE_COMPLETE',
      logical_resource_id: 'stubbed-resource-id',
      resource_type: 'stubbed-resource-type',
      timestamp: Time.now
    }.merge(attrs)
  end

  def stub_event(attrs = {})
    data = stub_event_data(attrs)
    id = data.delete(:event_id)
    Aws::CloudFormation::Event.new(id: id, data: data)
  end

end
