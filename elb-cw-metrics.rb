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

# AllELBMetrics
class AllELBMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: 'ELB'

  option :region,
         short: '-r REGION',
         long: '--region REGION',
         description: 'AWS Region (such as ap-northeast-1).',
         default: 'ap-northeast-1'

  option :elb_name,
         description: 'ELB name to retrieve metrics from CloudWatch',
         short: '-n ELB_NAME',
         long: '--name ELB_NAME'

  option :fetch_age,
         description: 'How long ago to fetch metrics for',
         short: '-f AGE',
         long: '--fetch_age',
         default: 60,
         proc: proc { |a| a.to_i }

  option :duration,
         description: 'Duration to collect metrics data',
         short: '-d DURATION',
         long: '--duration',
         default: 60,
         proc: proc { |a| a.to_i }

  def run
    if config[:scheme] == ''
      graphite_root = "#{config[:elb_name]}"
    else
      graphite_root = config[:scheme]
    end

    # please confirm the link
    # http://docs.aws.amazon.com/ElasticLoadBalancing/latest/
    # DeveloperGuide/US_MonitoringLoadBalancerWithCW.html
    statistic_type = {
      'HealthyHostCount' => 'Average',
      'UnHealthyHostCount' => 'Average',
      'RequestCount' => 'Sum',
      'Latency' => 'Average',
      'HTTPCode_ELB_4XX' => 'Sum',
      'HTTPCode_ELB_5XX' => 'Sum',
      'HTTPCode_Backend_2XX' => 'Sum',
      'HTTPCode_Backend_3XX' => 'Sum',
      'HTTPCode_Backend_4XX' => 'Sum',
      'HTTPCode_Backend_5XX' => 'Sum',
      'BackendConnectionErrors' => 'Sum',
      'SurgeQueueLength' => 'Maximum',
      'SpilloverCount' => 'Sum'
    }

    end_time = Time.now - config[:fetch_age]
    start_time = end_time - config[:duration]

    begin
      AWS.config(
        cloud_watch_endpoint: "monitoring.#{config[:region]}.amazonaws.com"
      )

      statistic_type.each do |metric_name, statistics_type|
        metric = AWS::CloudWatch::Metric.new(
          'AWS/ELB',
          metric_name,
          dimensions: [{
            name: 'LoadBalancerName',
            value: config[:elb_name]
          }]
        )
        stats = metric.statistics(
          start_time: start_time,
          end_time: end_time,
          statistics: [statistics_type]
        )
        last_stats = stats.sort_by { |stat| stat[:timestamp] }.last
        unless last_stats.nil?
          output graphite_root + ".#{config[:elb_name]}.#{metric_name}",
                 last_stats[statistics_type.downcase.to_sym].to_f,
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
