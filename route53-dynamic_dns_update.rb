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

require 'aws-sdk'
require 'net/http'

config = YAML.load_file('/etc/aws-route53.conf')

AWS.config({
  :access_key_id     => config['access_key_id'],
  :secret_access_key => ['secret_access_key']
})

hostname = Facter.hostname
domain   = config['domain']
zone     = config['zone_id']
ttl      = config['ttl']

metadata = 'http://169.254.169.254/latest/meta-data'

hostname_local  = Net::HTTP.get(URI.parse("#{metadata}/local-hostname"))
hostname_public = Net::HTTP.get(URI.parse("#{metadata}/public-hostname"))

records = [
  { :alias => "#{hostname}.p.#{domain}.", :target => hostname_local  },
  { :alias => "#{hostname}.#{domain}.",   :target => hostname_public }
]

record_sets = AWS::Route53::HostedZone.new(zone).rrsets

records.each do |record|
  new_record = record_sets[record[:alias], 'CNAME']

  new_record.delete if new_record.exists?

  record_sets.create(record[:alias], 'CNAME', :ttl => ttl, :resource_records => [{:value => record[:target]}])
end
