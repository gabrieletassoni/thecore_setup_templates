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

# Versioning on major versions, there is where breakage con occour
# minor versions and patches must be made backward compatible
output = run "gem search ^thecore$ -ra --source https://www.taris.it/gems-repo/", capture: true
gem_dependency = "s.add_dependency 'thecore'"
versions = output.match(/^[\s\t]*thecore \((.*)\)/)[1].split(", ") rescue []
unless versions.empty?
  answer = ask "Which version of thecore do you want to use?", :red, limited_to: versions
  say "You selected #{answer}"
  gem_dependency += ", '~> #{answer.split(".").first(2).join(".")}'"
end
# GEMSPEC
gsub_file "#{@name}.gemspec", 's.add_dependency', '# s.add_dependency'
gsub_file "#{@name}.gemspec", 's.add_development_dependency', '# s.add_development_dependency'

gsub_file "#{@name}.gemspec", 's.homepage', "s.homepage = 'https://www.taris.it' #"
gsub_file "#{@name}.gemspec", 's.summary', "s.summary = 'Thecorized #{@name}' #"
gsub_file "#{@name}.gemspec", 's.description', "s.description = 'Thecorized #{@name} full description.' #"

inject_into_file "#{@name}.gemspec", before: /^end/ do
"  #{gem_dependency}
"
end

# GEMFILE
add_source "https://www.taris.it/gems-repo" do
  gem 'thecore', "~> #{answer.split(".").first(2).join(".")}" # , path: '../../thecore_project/thecore'
end

gem 'sqlite3' # Necessario per rails quando faccio girare il tutto da engine

# Run bundle
run "bundle"

# then run thecorize_plugin generator
rails_command "g thecore:thecorize_plugin #{@name}"
