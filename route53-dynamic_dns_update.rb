#!/usr/bin/env ruby
#
# /etc/aws-route53.conf:
#
# access_key_id:
# secret_access_key:
# domain:
# zone_id:
# ttl:
#
# IAM permissions:
#
# {
#   "Statement": [
#     {
#       "Action": [
#         "route53:ChangeResourceRecordSets",
#         "route53:GetHostedZone",
#         "route53:ListResourceRecordSets"
#       ],
#       "Effect": "Allow",
#       "Resource": [
#         "arn:aws:route53:::hostedzone/<your hosted zone id>"
#       ]
#     }
#   ]
# }

require 'facter'
require 'aws-sdk'
require 'net/http'

config = YAML.load_file('/etc/aws-route53.conf')

route53 = AWS::Route53.new({
  :access_key_id     => config['access_key_id'],
  :secret_access_key => config['secret_access_key']
})

hostname = Facter.hostname
domain   = config['domain']
zone     = config['zone']
ttl      = config['ttl']

metadata = 'http://169.254.169.254/latest/meta-data'

hostname_ipv4 = Net::HTTP.get(URI.parse("#{metadata}/local-ipv4"))
public_ipv4    = Net::HTTP.get(URI.parse("#{metadata}/public-ipv4"))

local_record = {
  :alias  => "#{hostname}-private.#{domain}.",
  :target => hostname_ipv4
}

public_record = {
  :alias  => "#{hostname}.#{domain}.",
  :target => public_ipv4
}

records = []
records.push local_record  if hostname_ipv4
records.push public_record if public_ipv4

record_sets = route53.hosted_zones[zone].resource_record_sets

records.each do |record|
  new_record = record_sets[record[:alias], 'A']

  new_record.delete if new_record.exists?

  new_record = {
    :name    => record[:alias],
    :type    => 'A',
    :options => {
      :ttl              => ttl,
      :resource_records => [{ :value => record[:target] }]
    }
  }

  record_sets.create(new_record[:name], new_record[:type], new_record[:options])
end
