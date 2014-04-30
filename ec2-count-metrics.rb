#!/usr/bin/env ruby
#
# Retrieve EC2 instance count
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
         default: 'EC2'

  option :region,
         short: '-r REGION',
         long: '--region REGION',
         description: 'AWS Region (such as ap-northeast-1).',
         default: 'ap-northeast-1'

  def run
    graphite_root = config[:scheme]

    begin
      ec2 = AWS::EC2.new(region: config[:region])
      output graphite_root + ".#{config[:region]}.count",
          ec2.instances.select { |i| i.status == :running }.count
    rescue AWS::Errors::Base => e
      puts "Error: exception: #{e}"
      critical
    end
    ok
  end
end
