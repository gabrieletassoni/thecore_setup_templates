# Adding gitignore file
gitignr = open('https://raw.githubusercontent.com/gabrieletassoni/thecore_thor_scripts/master/thor_templates/gitignore', &:read)
create_file '.gitignore', gitignr

git :init
git add: '.gitignore'
git commit: "-a -m 'Added gitignore'"
git add: '. -A'
git commit: "-a -m 'First commit'"
remote_origin = ask("Please provide git repository for this gem, leave empty for not providing one:\n", :green, :bold)
git remote: "add origin #{remote_origin}" unless remote_origin.blank?
