#! /usr/bin/env ruby
require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'net/http'
require 'net/https'
require 'uri'
require 'socket'
require 'crack'

class NewRelicAll < Sensu::Plugin::Metric::CLI::Graphite
  option :apikey,
         short: '-k APIKEY',
         long: '--apikey APIKEY',
         description: 'Your New Relic API Key',
         required: true

  def run
    url  = 'https://api.newrelic.com'
    parsed_url = URI.parse(url)
    http = Net::HTTP.new(parsed_url.host, parsed_url.port)
    req  = Net::HTTP::Get.new('/v2/applications.xml')
    req.add_field('x-api-key', config[:apikey])
    http.use_ssl = true
    res = http.request(req)

    stats = Crack::XML.parse(res.body)
    apps = Array.new

    stats['applications_response']['applications']['application'].each do |app|
      if app['reporting'] == 'false'
        apps << {
          :name => app['name'],
          :status => app['health_status'],
          :reporting => false
        }
      else
        apps << {
          :name => app['name'],
          :status => app['health_status'],
          :reporting => true,
          :settings => {
            :response_time => app['application_summary']['response_time'],
            :throughput => app['application_summary']['throughput'],
            :error_rate => app['application_summary']['error_rate'],
            :apdex => app['application_summary']['apdex_score'],
          }
        }
      end
    end

    apps.each do |a|
      if a[:reporting]
        output "#{a[:name].downcase}.response_time", a[:settings][:response_time]
        output "#{a[:name].downcase}.throughput", a[:settings][:throughput]
        output "#{a[:name].downcase}.error_rate", a[:settings][:error_rate]
        output "#{a[:name].downcase}.apdex", a[:settings][:apdex]
      end
    end

  end
end
