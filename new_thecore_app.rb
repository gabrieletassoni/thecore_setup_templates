require 'open-uri'
# Asking which thecore gem to install
output = run 'gem search ^thecore$ -ra', capture: true
versions = (output.match(/^[\s\t]*thecore \((.*)\)/)[1].split(', ') rescue [] )

version = "~> #{versions.first.split('.').first(2).join('.') rescue '1.0' }"
say "Installing thecore version #{version}"
gem 'thecore', version # , path: '../../thecore_project/thecore'

# Adding base gems
gem 'thecore_settings', '~> 1.1', require: 'thecore_settings'
# Do you want REST API?
gem 'thecore_api', '~> 1.1', require: 'thecore_api' if yes? 'Do you want REST API capability for your thecore application?', :red

# Asking which thecore theme to install
output = run 'gem search ^thecore_.*$ -ra', capture: true
themes = {}
output.split("\n").each do |line|
  match = line.match /^(thecore_theme_.*) \((.*)\)$/
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

apply "https://raw.githubusercontent.com/gabrieletassoni/thecore_setup_templates/master/thecore_git_management.rb"
