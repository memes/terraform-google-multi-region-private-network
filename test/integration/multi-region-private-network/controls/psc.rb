# frozen_string_literal: true

require 'json'

# rubocop:disable Metrics/BlockLength
control 'psc' do
  title 'Ensure PSC meets expectations'
  impact 1.0
  project = input('input_project_id')
  name = input('input_name')
  network = input('output_self_link')
  options = JSON.parse(input('output_options_json'), { symbolize_names: true })
  psc = JSON.parse(input('output_psc_json'), { symbolize_names: true })

  expected_count = psc.nil? || psc[:address].nil? || psc[:address].empty? ? 0 : 1
  describe google_compute_global_addresses(project:).where(name:) do
    its('count') { should eq expected_count }
    unless expected_count.zero?
      its('addresses') { should include psc[:address] }
      its('address_types') { should include 'INTERNAL' }
      its('purposes') { should include 'PRIVATE_SERVICE_CONNECT' }
      its('networks') { should include network }
    end
  end
  expected_target = options.nil? || options[:enable_restricted_apis_access] ? 'vpc-sc' : 'all-apis'
  describe google_compute_global_forwarding_rules(project:).where(name: name.delete('^a-z0-9').slice(0, 20)) do
    its('count') { should eq expected_count }
    unless expected_count.zero?
      its('targets') { should include expected_target }
      its('networks') { should include network }
      its('ip_addresses') { should include psc[:address] }
      its('load_balancing_schemes') { should include nil }
    end
  end
end
# rubocop:enable Metrics/BlockLength
