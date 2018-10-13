# Edit GEMSPEC
# Remove all dependencies created from the standard rails new command
gsub_file "#{name}.gemspec", 's.add_dependency', '# s.add_dependency'
gsub_file "#{name}.gemspec", 's.add_development_dependency', '# s.add_development_dependency'

gsub_file "#{name}.gemspec", 's.homepage', "s.homepage = 'https://github.com/gabrieletassoni/thecore' #"
gsub_file "#{name}.gemspec", 's.summary', "s.summary = 'Thecorized #{name}' #"
gsub_file "#{name}.gemspec", 's.description', "s.description = 'Thecorized #{name} full description.' #"

# Getting higher version of thecore
output = run 'gem search ^thecore$ -ra', capture: true
versions = (begin
              output.match(/^[\s\t]*thecore \((.*)\)/)[1].split(', ')
            rescue StandardError
              []
            end)

version = "~> #{begin
                  versions.first.split('.').first(2).join('.')
                rescue StandardError
                  '1.0'
                end}"
inject_into_file "#{name}.gemspec", before: /^end/ do
"    s.add_dependency 'thecore', '#{version}'\n"
end

inject_into_file "lib/#{name}.rb", before: /^module #{Thor::Util.camel_case(name)}$/ do
"require 'thecore'\n"
end

# then run thecorize_component
rails_command "app:template LOCATION='https://raw.githubusercontent.com/gabrieletassoni/thecore_thor_scripts/master/thecorize_component.rb'"
