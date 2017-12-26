thecore_version = "1.0".freeze

run "gem install bundler --no-ri --no-rdoc", capture: false
current_gem_user = run "bundle config www.taris.it", capture: true
# Set for the current user (/Users/iltasu/.bundle/config): "bah"
credentials = current_gem_user.match(/^[\s\t]*Set for the current user .*: "(.*)"/)[1] rescue nil

if(credentials.blank? || yes?("Credentials already set, do you want to change them?", :red))
  username = ask "Please provide your username: ", :red
  password = ask "Please provide your password: ", :red
  credentials = "#{username}:#{password}"
  run "bundle config www.taris.it '#{credentials}'"
  run "gem sources --add 'https://#{credentials}@www.taris.it/gems-repo/'"
end

# GEMSPEC
gsub_file "#{@name}.gemspec", 's.add_dependency', '# s.add_dependency'
gsub_file "#{@name}.gemspec", 's.add_development_dependency', '# s.add_development_dependency'

gsub_file "#{@name}.gemspec", 's.homepage', "s.homepage = 'https://www.taris.it' #"
gsub_file "#{@name}.gemspec", 's.summary', "s.summary = 'Thecorized #{@name}' #"
gsub_file "#{@name}.gemspec", 's.description', "s.description = 'Thecorized #{@name} full description.' #"

inject_into_file "#{@name}.gemspec", before: /^end/ do
"  s.add_dependency 'thecore', '~> #{thecore_version}'\n"
end

inject_into_file "lib/#{@name}/engine.rb", before: /^module #{Thor::Util.camel_case(@name)}$/ do
"require 'thecore'\n"
end

# GEMFILE
add_source "https://www.taris.it/gems-repo" do
  gem 'thecore', "~> #{answer.split(".").first(2).join(".") rescue '1.0'}" # , path: '../../thecore_project/thecore'
end

gem 'sqlite3' # Necessario per rails quando faccio girare il tutto da engine

# Run bundle
run "bundle"

# then run thecorize_plugin generator
rails_command "g thecore:thecorize_plugin #{@name}"
