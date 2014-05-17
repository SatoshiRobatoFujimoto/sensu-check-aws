#!/usr/bin/env ruby
#
# Retrieve All ELB metrics from CloudWatch
# ===
#
# Copyright 2014 Ryutaro YOSHIBA http://www.ryuzee.com/
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'aws-sdk'
require 'json'

# AllELBMetrics
class AllELBMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: 'billing'

  option :fetch_age,
         description: 'How long ago to fetch metrics for',
         short: '-f AGE',
         long: '--fetch_age',
         default: 7200,
         proc: proc { |a| a.to_i }

  option :duration,
         description: 'Duration to collect metrics data',
         short: '-d DURATION',
         long: '--duration',
         default: 7200,
         proc: proc { |a| a.to_i }

  def run
    if config[:scheme] == ''
      graphite_root = "billing"
    else
      graphite_root = config[:scheme]
    end

    conf = {} 
    begin
      conf = JSON.parse(File.read(File.dirname(__FILE__)+"/billing-metrics.json"))
    rescue
      conf["billing"] = []
    end
    statistic_type = conf["billing"]
    statistic_type.unshift("all");

    end_time = Time.now - config[:fetch_age]
    start_time = end_time - config[:duration]

    begin
      AWS.config(
        cloud_watch_endpoint: "monitoring.us-east-1.amazonaws.com"
      )
      dimension = {
        dimensions: [
        {
          name: 'Currency',
          value: 'USD'
        }
        ]
      }

      statistic_type.each do |metric_name|
        if metric_name != "all" then
          dimension[:dimensions].push({name: 'ServiceName', value: metric_name})
        end
        metric = AWS::CloudWatch::Metric.new(
          'AWS/Billing',
          'EstimatedCharges',
          dimension
        )
        stats = metric.statistics(
          start_time: start_time,
          end_time: end_time,
          statistics: ["Average"]
        )
        last_stats = stats.sort_by { |stat| stat[:timestamp] }.last
        unless last_stats.nil?
          output graphite_root + ".service.#{metric_name}",
                 last_stats[:average].to_f,
                 last_stats[:timestamp].to_i
        end
      end
    rescue Exception => e
      puts "Error: exception: #{e}"
      critical
    end
    ok
  end
end
