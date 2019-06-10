# Edit GEMSPEC
# Remove all dependencies created from the standard rails new command
gsub_file "#{name}.gemspec", 'spec.add_dependency', '# spec.add_dependency'
gsub_file "#{name}.gemspec", 'spec.add_development_dependency', '# spec.add_development_dependency'

homepage = ask("Please provide url for this component's project page (i.e. https://github.com/gabrieletassoni/#{name}):\n")
summary = ask("Please provide a short description for this component:\n")
description = ask("Please provide a longer description for this component:\n")

gsub_file "#{name}.gemspec", 'spec.homepage', "spec.homepage = '#{homepage.presence || "https://github.com/gabrieletassoni/thecore"}' #"
gsub_file "#{name}.gemspec", 'spec.summary', "spec.summary = '#{summary.presence || "Thecorized #{name}"}' #"
gsub_file "#{name}.gemspec", 'spec.description', "spec.description = '#{description.presence || "Thecorized #{name} full description."}' #"

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
"  spec.add_dependency 'thecore', '#{version}'\n"
end

inject_into_file "lib/#{name}.rb", before: /^module #{Thor::Util.camel_case(name)}$/ do
"require 'thecore'\n"
end

say "Starting to apply deeper customizations in order to thecorize the component", :green
# Creating a thecore root component
if yes? "Is this component a root action (A general action which is shown in the root menu of Thecore app and is not directly linked with a model)?", :red
  # make this a rails_admin plugin
  apply "https://gist.github.com/bbenezech/1621146/raw/5268788e715397bf476c83d76d335f152095e659/rails_admin_action_creator"
  # make the rails admin plugin a root action
  apply 'https://raw.githubusercontent.com/gabrieletassoni/thecore_setup_templates/master/thecore_make_root_action.rb'
  # Add more components
  if yes? "Do this component needs to interact with a Datawedge or a Keyboard emulation scanner?", :red
    apply 'https://raw.githubusercontent.com/gabrieletassoni/thecore_setup_templates/master/thecore_add_datawedge_to_root_action.rb'
  end
end
# Run component thecorization
apply "https://raw.githubusercontent.com/gabrieletassoni/thecore_setup_templates/master/thecorize_component.rb"
# Make this git more groovy
apply "https://raw.githubusercontent.com/gabrieletassoni/thecore_setup_templates/master/thecore_git_management.rb"
