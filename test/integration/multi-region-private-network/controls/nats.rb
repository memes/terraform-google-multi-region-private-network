# frozen_string_literal: true

require 'json'

control 'nats' do
  title 'Ensure Cloud Routers and Cloud NATs meet expectations'
  impact 1.0
  self_link = input('output_self_link')
  project_id = input('input_project_id')
  regions = input('input_regions').gsub(/(?:[\[\]]|\\?")/, '').gsub(', ', ',').split(',')
  options = JSON.parse(input('output_options_json'), { symbolize_names: true })

  router_count = options[:nat] ? regions.length : 0
  regions.each_with_index do |region, _index|
    describe region do
      expected_count, msg = if router_count.zero?
                              [0, 'Cloud Router and Cloud NAT should not exist']
                            else
                              [1, 'Cloud Router and Cloud NAT should exist']
                            end
      it msg do
        routers = google_compute_routers(project: project_id, region: region).where(network: self_link)
        expect(routers.count).to cmp expected_count
        nats = google_compute_router_nats(project: project_id, region: region, router: routers.names.first)
        expect(nats.count).to cmp expected_count
      end
    end
  end
end
