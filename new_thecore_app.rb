require 'open-uri'

def add_gem gem_name
  output = run "gem search ^#{gem_name}$ -ra", capture: true
  versions = (output.match(/^[\s\t]*#{gem_name} \((.*)\)/)[1].split(', ') rescue [] )

  version = "~> #{versions.first.split('.').first(2).join('.') rescue '1.0' }"
  say "Installing #{gem_name} version #{version}"
  gem gem_name, version, require: gem_name # , path: '../../thecore_project/thecore'
end

loop do
  answr = ask "Would you like to add a private source to the Gemfile (i.e. http://code.whytheluckystiff.net)? Answer NONE to skip this step.\n", :green, :bold
  break if answr.upcase == "NONE"
  add_source answr
end

# Adding base gems
gem 'rails-erd', group: :development

add_gem "thecore"
add_gem 'thecore_settings'
# Do you want REST API?
add_gem 'thecore_api' if yes?('Do you want REST API capability for your thecore application?', :green)

# Asking which thecore theme to install
output = run 'gem search ^thecore_.*$ -ra', capture: true
themes = {}
output.split("\n").each do |line|
  match = line.match(/^(thecore_theme_.*) \((.*)\)$/)
  next if match.blank?
  version = "~> #{match[2].split(',').first.delete('(').split('.').first(2).join('.') rescue '1.0'}"
  themes[match[1]] = version
end

theme = ask("Which theme for thecore do you want to use?\n", :green, :bold, limited_to: themes.keys, default: themes.keys.first)
say "You selected #{theme}"
gem theme, themes[theme], require: theme

get "https://raw.githubusercontent.com/rails/webpacker/master/lib/install/config/webpacker.yml", "config/webpacker.yml"
run 'rails webpacker:install'
# Run bundle
run 'bundle'
run 'bundle exec rails g erd:install'

# remove the index.html
remove_file 'public/index.html'

# Add thecore references to js and css
# *= require thecore to application.css before */
# //= require thecore to application.js before //= require_tree .
inject_into_file 'app/assets/javascripts/application.js', before: '//= require_tree .' do
  "//= require thecore\n"
end
inject_into_file 'app/assets/stylesheets/application.css', before: '*/ .' do
  "*= require thecore\n"
end

# TODO: remove from application controller the protect_from_forgery with: :exception part
gsub_file 'app/controllers/application_controller.rb', 'protect_from_forgery with: :exception', ''

# Add Uglifier armony for ES6 compatibility
gsub_file 'config/environments/production.rb', "config.assets.js_compressor", "# config.assets.js_compressor"
inject_into_file 'config/environments/production.rb', after: "# Compress JavaScripts and CSS.\n" do
  "  config.assets.js_compressor = Uglifier.new(:harmony => true)\n"
end

apply "https://raw.githubusercontent.com/gabrieletassoni/thecore_setup_templates/master/thecore_git_management.rb"

# inside('../') do
# # TODO: Remove if I can't find a way to interact with the run
# say("Creating components for the project")
#   loop do
#     break unless yes?("Would you like to add a thecore component to this project?", :green)
#     component_name = ask("Please enter component's name:\n")
#     break unless component_name.match?(/^[a-zA-Z_-]+$/)
#     rails "plugin new '#{component_name}' -m 'https://raw.githubusercontent.com/gabrieletassoni/thecore_setup_templates/master/new_thecore_component.rb' --full"
#     # run('curl -s https://raw.githubusercontent.com/gabrieletassoni/thecore_setup_templates/master/bin/create_thecore_component | bash')
#   end
# end