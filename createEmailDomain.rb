#!/usr/bin/env ruby

require 'find'
require 'fileutils'
require 'optparse'
require 'English'
require 'yaml'

DEFAULT_EMAIL = 'evmadmin@example.com'.freeze

options = {}
opt_parser = OptionParser.new do |opt|
  opt.banner = 'Usage: createEmailDomain.rb -r <old datastore root> -d <new domain> -e <new default email address>'
  options[:root] = Dir.pwd
  opt.on('-r', '--root Datastore root', 'Existing Datastores') do |root|
    options[:root] = root
  end

  options[:domain] = nil
  opt.on('-d', '--domain DOMAIN', 'New Domain') do |domain|
    options[:domain] = domain
  end
  options[:email] = nil
  opt.on('-e', '--email ADDRESS', 'New Default Email address') do |addr|
    options[:email] = addr
  end
  @verbose = false
  opt.on('-v', '--verbose', 'New Default Email address') do |verbose|
    @verbose = true
  end
end


begin
  opt_parser.parse!
  mandatory = %i[domain email] # Enforce the presence of
  missing = mandatory.select { |param| options[param].nil? } # the -t and -f switches
  unless missing.empty? #
    raise OptionParser::MissingArgument, missing.join(', ')
  end #
rescue OptionParser::InvalidOption, OptionParser::MissingArgument #
  puts $ERROR_INFO.to_s # Friendly output when parsing fails
  puts opt_parser #
  exit #
end

puts options if @verbose

# Create the __domain__.yaml

domain_yaml = <<~EOT
  ---
  object_type: domain
  version: 1.0
  object:
    attributes:
      name: #{options[:domain]}
      description: Email Settings domain
      display_name: 
      priority: 50
      enabled: true
      tenant_id: 1000000000001
      source: user
      top_level_namespace: 
EOT

@namespace_tmpl = <<~EOT
  ---
  object_type: namespace
  version: 1.0
  object:
    attributes:
      name: %{tmpl_name}
      description: 
      display_name: 
      priority: 
      enabled:
EOT

def add_metadata_to_path(root, path)
  puts "add_metadata_to_path([#{path}])" if @verbose
  # blah.class/__class__.yaml ... created because copied
  if path.split('/').last =~ /\.class$/
    puts "\tNothing do do! recurse" if @verbose
    add_metadata_to_path(root, path.split('/').reverse.drop(1).reverse.join('/'))
  else
    namespace_f_name = path + '/__namespace__.yaml'
    new_namespace = path.split('/')[-1]
    unless File.exist?(namespace_f_name)
      puts "\tCreating namesspace [#{new_namespace}] metadata file for #{path}" if @verbose
      File.open(namespace_f_name, 'w') { |f|
        f.puts @namespace_tmpl % { tmpl_name: new_namespace }
      }

    end
    add_metadata_to_path(root, path.split('/').reverse.drop(1).reverse.join('/')) unless path.split('/').size == 2
  end
end

FileUtils.mkdir_p(options[:domain]) unless File.directory?(options[:domain])
domain_f_name = options[:domain] + '/__domain__.yaml'
File.open(domain_f_name, 'w') { |f| f.puts domain_yaml } unless File.exist?(domain_f_name)

instances = []
puts "ROOT: #{options[:root]}" if @verbose
Find.find(options[:root]) do |path|
  puts "path: [#{path}]" if @verbose
  # We only care about items in the default domains
  next unless path =~ %r{^#{options[:root]}(ManageIQ|RedHat)}
  # ... which are YAML files
  next unless path =~ /yaml$/
  puts "\t checking" if @verbose
  file = File.open(path, 'rb')
  data = file.read

  next unless data =~ /#{DEFAULT_EMAIL}/

  puts "\t\tmatch" if @verbose
  frag = path.gsub(%r{#{options[:root]}}, '')
  puts "Frag: [#{frag}]" if @verbose
  new_dir = "./#{options[:domain]}" + '/' + frag.split('/').drop(2).reverse.drop(1).reverse.join('/')

  FileUtils.mkdir_p(new_dir) unless File.directory?(new_dir)

  add_metadata_to_path(options[:root], new_dir)

  new_file_name = new_dir + '/' + path.split('/').last

  new_data = data.gsub(/#{DEFAULT_EMAIL}/, options[:email])
  puts "Creating new file [#{new_file_name}]" if @verbose
  File.open(new_file_name, 'w') { |nf| nf.puts new_data }

  old_dir = path.split('/').reverse.drop(1).reverse.join('/')
  puts "old_dir: [#{old_dir}]" if @verbose
  next unless old_dir =~ /\.class$/
  dir_files = Dir.entries(old_dir)
  dir_files.each { |df|
    next unless df =~ /yaml$/
    next if df =~ /__class__.yaml$/
    old = old_dir + '/' + df
    new = new_dir + '/' + df
    puts "copying [#{old}] to [#{new}]" if @verbose
    FileUtils.copy(old, new)
    instances << new.gsub(%r{^.}, '').gsub(%r{\.class}, '').gsub(/\.yaml$/, '')
  }
end

instancesStr = '[' + instances.join(', ') + ']'

FileUtils.copy_entry 'Code', options[:domain] + '/Code'

yaml_conf = options[:domain] + '/Code/ProcessEmailConfig.class/updateemailconfigs.yaml'
data = YAML.load_file yaml_conf


data['object']['fields'][0]['instances']['value'] = instancesStr
File.open(yaml_conf, 'w') { |f| YAML.dump(data, f) }

`zip -r #{options[:domain]}.zip #{options[:domain]}/`