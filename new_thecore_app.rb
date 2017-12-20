require 'net/dav'
# Selecting the gems needed
current_gem_user = run "bundle config www.taris.it", capture: true
# Set for the current user (/Users/iltasu/.bundle/config): "bah"
credentials = current_gem_user.match(/^[\s\t]*Set for the current user .*: "(.*)"/)[1] rescue nil

if credentials.blank? || yes?("Credentials already set, do you want to change them?", :red)
  username = ask "Please provide your username: ", :red
  password = ask "Please provide your password: ", :red
  credentials = "#{username}:#{password}"
  run "bundle config www.taris.it '#{credentials}'"
  run "gem sources --add 'https://#{credentials}@www.taris.it/gems-repo/'"
end

gems_repo = "https://www.taris.it/gems-repo/"

add_source gems_repo do
  output = run "gem search ^thecore$ -ra --source #{gems_repo}", capture: true
  versions = (output.match(/^[\s\t]*thecore \((.*)\)/)[1].split(", ") rescue [])
  unless versions.empty?
    answer = ask "Which version of thecore do you want to use?", :red, limited_to: versions
    say "You selected #{answer}"
  end
  gem 'thecore', "~> #{answer.split(".").first(2).join(".")}" # , path: '../../thecore_project/thecore'

  all_gems_in_source = run "gem search -r --source #{gems_repo}", capture: true

  dav = Net::DAV.new(gems_repo, :curl => false)
  dav.verify_server = false
  dav.credentials(*(credentials.split(":")))

  useful_gems = []
  dav.find('.',:recursive=>true,:suppress_errors=>true,:filename=>/\.gem$/) do | item |
    thegem = item.url.to_s[/(thecore_.*|rails_admin_.*)\-.*\.gem$/, 1]
    useful_gems.push(thegem) unless thegem.nil? || thegem.empty?
  end

  useful_gems.each do |u_gem|
    gem u_gem if u_gem.include?("thecore_") && yes?("Would you like to use the gem '#{u_gem}' for this project?", :red)
  end

  useful_gems.each do |u_gem|
    gem u_gem if u_gem.include?("rails_admin_") && yes?("Would you like to use the gem '#{u_gem}' for this project?", :red)
  end
end

# Run bundle
run "bundle"

# then run thecorize_plugin generator
rails_command "g thecore:thecorize_app #{@name}"

# DB
rails_command "db:create"
rails_command "db:migrate"
