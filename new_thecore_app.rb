require 'open-uri'
# Asking which thecore gem to install
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
  version = "~> #{begin
                    match[2].split(',').first.delete('(').split('.').first(2).join('.')
                  rescue StandardError
                    '1.0'
                  end}"
  themes[match[1]] = version
end

theme = ask 'Which theme for thecore do you want to use?', :red, limited_to: themes.keys
say "You selected #{theme}"
gem theme, themes[theme], require: theme

# Run bundle
run 'bundle'

# remove the index.html
remove_file 'public/index.html'

# Add thecore references to js and css
# *= require thecore to application.css before */
# //= require thecore to application.js before //= require_tree .
inject_into_file 'app/assets/javascripts/application.js', before: '//= require_tree .' do
  "//= require thecore"
end
inject_into_file 'app/assets/stylesheets/application.css', before: '*/ .' do
  "*= require thecore"
end

# TODO: remove from application controller the protect_from_forgery with: :exception part
gsub_file 'app/controllers/application_controller.rb', 'protect_from_forgery with: :exception', ''

# Adding gitignore file
gitignr = open('https://raw.githubusercontent.com/gabrieletassoni/thecore_thor_scripts/master/thor_templates/gitignore', &:read)
create_file '.gitignore', gitignr

git :init
git add: '.gitignore'
git commit: "-a -m 'Added gitignore'"
git add: '. -A'
git commit: "-a -m 'First commit'"
Dir.chdir('.git/hooks') do
  begin
    File.rename('post-update.sample', 'post-update')
  rescue StandardError
    nil
  end
  system 'chmod +x post-update'
end
