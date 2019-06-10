# Adding gitignore file
gitignr = open('https://raw.githubusercontent.com/gabrieletassoni/thecore_thor_scripts/master/thor_templates/gitignore', &:read)
create_file '.gitignore', gitignr

git :init
git add: '.gitignore'
git commit: "-a -m 'Added gitignore'"
git add: '. -A'
git commit: "-a -m 'First commit'"
# Dir.chdir('.git/hooks') do
#  begin
#    File.rename('post-update.sample', 'post-update')
#  rescue StandardError
#    nil
#  end
#  system 'chmod +x post-update'
# end
