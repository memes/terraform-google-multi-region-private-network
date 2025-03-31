# frozen_string_literal: true

require 'json'

control 'nats' do
  title 'Ensure Cloud Routers and Cloud NATs meet expectations'
  impact 1.0
  network = input('output_self_link')
  project = input('input_project_id')
  regions = input('input_regions').gsub(/(?:[\[\]]|\\?")/, '').gsub(', ', ',').split(',')
  nat = JSON.parse(input('output_nat_json'), { symbolize_names: true })

  router_count = nat.nil? ? 0 : regions.length
  logging_enabled = !(nat.nil? || nat[:logging_filter].nil? || nat[:logging_filter].empty?)
  regions.each_with_index do |region, _index|
    describe region do
      expected_count, msg = if router_count.zero?
                              [0, 'Cloud Router and Cloud NAT should not exist']
                            else
                              [1, 'Cloud Router and Cloud NAT should exist']
                            end
      it msg do
        routers = google_compute_routers(project:, region:).where(network:)
        expect(routers.count).to cmp expected_count
        nats = google_compute_router_nats(project:, region:, router: routers.names.first)
        expect(nats.count).to cmp expected_count
        expect(nats.log_configs.first.enable).to eq logging_enabled if nats.count.positive?
      end
    end
  end
end
