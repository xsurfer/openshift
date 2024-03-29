#!/usr/bin/ruby

require 'rubygems'
require 'rest-client'
require 'stickshift-node'
require 'pp'
require 'json'

#$create_url='curl -k -X POST -H "Accept: application/xml" --user "%s:%s" https://%s/broker/rest/domains/%s/applications'
#$scale_url="#{$create_url}/%s/events"

$base_url='https://%s/broker/rest'
$create_url='/domains/%s/applications'
$scale_url='/domains/%s/applications/%s/events'
$cartridges_url='/cartridges'
$domain_url='/domains'

class Gear_scale_ctl
  def initialize(action, opts)
    if action ==  'gear-scale-ctl.rb'
      $stderr.puts 'Call gear-scale-ctl via an alias: add-gear, remove-gear'
      exit 2
    end

    if not ['add-gear', 'remove-gear'].include? action
      usage opts
    end

    @action = action
    @opts = opts

    base_url = "#{$base_url % opts["server"]}#{$scale_url % [opts['namespace'], opts['app']]}"
    params = {
        'broker_auth_key' => File.read("/var/lib/stickshift/#{opts['uuid']}/.auth/token"),
        'broker_auth_iv' => File.read("/var/lib/stickshift/#{opts['uuid']}/.auth/iv")
    }
    return if not check_scalability(params, action, opts)

    params['event'] = 'add-gear' == action ?  'scale-up' : 'scale-down'

    request = RestClient::Request.new(:method => :post, :url => base_url, :timeout => 600,
        :headers => {:accept => 'application/json', :user_agent => 'StickShift'},
        :payload => params
        )

    begin
      response = request.execute()
      if 300 <= response.code
        raise response
      end
    rescue RestClient::UnprocessableEntity => e
      if action == "add-gear"
        puts "Already at the maximum number of gears allowed for either the app or your account."
      elsif action == "remove-gear"
        puts "Already at the minimum number of gears required for this application."
      else
        puts "The #{action} request could not be processed."
      end
      return false
    rescue RestClient::ExceptionWithResponse => e
      $stderr.puts "The #{action} request failed with http_code: #{e.http_code}"
      return false
    rescue RestClient::Exception => e
      $stderr.puts "The #{action} request failed with the following exception: #{e.to_s}"
      return false
    end
  end

  def check_scalability(params, action, opts)
    env = load_env(opts)
    data_dir = env['OPENSHIFT_DATA_DIR']
    scale_file = "#{data_dir}/scale_limits.txt"
    min = 1
    max = -1
    if not File.exists? scale_file
      gear_info_url = "#{$base_url % opts["server"]}#{$create_url % opts['namespace']}/#{opts['app']}"
      request = RestClient::Request.new(:method => :get, :url => gear_info_url, :timeout => 120,
          :headers => {:accept => 'application/json', :user_agent => 'StickShift'},
          :payload => params
          )

      begin
        response = request.execute()
        if 300 <= response.code
          return false
        end
      rescue RestClient::Exception => e
        $stderr.puts "Failed to get application info from the broker."
        return false
      end

      begin
        response_object = JSON.parse(response)
        min = response_object["data"]["scale_min"]
        max = response_object["data"]["scale_max"]
      rescue
        $stderr.puts "Could not use the application info response."
        return false
      end

      f = File.open(scale_file, 'w')
      f.write("scale_min=#{min}\nscale_max=#{max}")
      f.close
    else

      begin
        scale_data = File.read(scale_file)
        scale_hash = {}
        scale_data.split("\n").each { |s|
          line = s.split("=")
          scale_hash[line[0]] = line[1]
        }
        min = scale_hash["scale_min"].to_i
        max = scale_hash["scale_max"].to_i
      rescue => e
        $stderr.puts "Could not read or parse #{scale_file}"
        begin
          # Get it fresh from the broker next invocation
          File.unlink(scale_file)
        rescue
        end
        return false
      end
    end

    haproxy_conf_dir=File.join(env['OPENSHIFT_HOMEDIR'], "haproxy-1.4", "conf")
    gear_registry_db=File.join(haproxy_conf_dir, "gear-registry.db")
    current_gear_count = `wc -l #{gear_registry_db}`
    current_gear_count = current_gear_count.split(' ')[0].to_i
    if action=='add-gear' and current_gear_count == max
      $stderr.puts "Cannot add gear because max limit '#{max}' reached."
      return false
    elsif action=='remove-gear' and current_gear_count == min
      $stderr.puts "Cannot remove gear because min limit '#{min}' reached."
      return false
    end
    return true
  end

  def load_env(opts)
    env = {}
    # Load environment variables into a hash
    
    Dir["/var/lib/stickshift/#{opts['uuid']}/.env/*"].each { | f |
      next if File.directory?(f)
      contents = nil
      File.open(f) {|input|
        contents = input.read.chomp
        index = contents.index('=')
        contents = contents[(index + 1)..-1]
        contents = contents[/'(.*)'/, 1] if contents.start_with?("'")
        contents = contents[/"(.*)"/, 1] if contents.start_with?('"')
      }
      env[File.basename(f)] =  contents
    }
    env
  end

end

def usage
  $stderr.puts <<USAGE

Usage:

Add gear to application:
  Usage: add-gear -a|--app <application name> -u|--uuid <user> -n|--namespace <namespace uuid> [-h|--host <hostname>]

Remove gear from application:
  Usage: remove-gear -a|--app <application name> -u|--uuid <user> -n|--namespace <namespace uuid> [-h|--host <hostname>]

  -a|--app         application name  Name for your application (alphanumeric - max <rest call?> chars) (required)
  -u|--uuid        application uuid  UUID for your application (required)
  -n|--namespace   namespace    Namespace for your application(s) (alphanumeric - max <rest call?> chars) (required)
  -h|--host        libra server host running broker

USAGE
  exit! 255
end

config = StickShift::Config.instance

opts = {
    'server' => config.get('BROKER_HOST')
}

begin
  args = GetoptLong.new(
    ['--app',       '-a', GetoptLong::REQUIRED_ARGUMENT],
    ['--uuid',      '-u', GetoptLong::REQUIRED_ARGUMENT],
    ['--namespace', '-n', GetoptLong::REQUIRED_ARGUMENT],
    ['--server',    '-s', GetoptLong::REQUIRED_ARGUMENT]
  )

  args.each {|opt, arg| opts[opt[2..-1]] = arg.to_s}

  if 0 != ARGV.length
    usage
  end

  if opts['server'].nil? || opts['server'].empty? \
        || opts['app'].nil? || opts['app'].empty? \
        || opts['uuid'].nil? || opts['uuid'].empty? \
        || opts['namespace'].nil? || opts['namespace'].empty?
    usage
  end
rescue Exception => e
  usage
end

o = Gear_scale_ctl.new(File.basename($0), opts)

exit 0
