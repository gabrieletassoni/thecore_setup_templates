class ManageProjectsWorkingDir < Thor
  # To get your hands on the `from_superclass` method
  include Thor::Base

  # What we're interested in…
  include Thor::Actions

  Thor::Sandbox::ManageProjectsWorkingDir.source_root(File.join(Dir.pwd, "thor_templates"))

  desc "Reports status of folders in the working DIR", "Gives informations about already gitted folders, still not gitted ones and mistakenly structured ones."
  def status dir
    not_gitted = []
    mistaken = []
    Dir.chdir dir do
      Dir.glob("./*/*/*").each do |d|
        if File.directory? d
          say "Git exists in: #{d}", :green if File.exists? File.join(d, ".git")
          not_gitted.push(File.join(dir, d)) unless File.exists? File.join(d, ".git")
        else
          # Not a DIR, thus is a mistake in organization
          mistaken.push Pathname.new(File.join(dir, d)).parent
        end
      end
    end
    true_ungits = not_gitted.compact.uniq - mistaken.compact.uniq
    true_ungits.each do |ungit|
      say "Git does not exists in: #{ungit}", :yellow
    end
    mistaken.compact.uniq.each do |mis|
      say "There are mistakes in: #{mis}", :red
    end
  end

  desc "Traversing the DIR structures it adds git remote URL", "By checking wether or not the .git folder exists, it inits or changes the url."
  def update_or_init_git_remote dir, url
    Dir.chdir dir do
      Dir.glob("./*/*/*").each do |d|
        if File.directory? d
          origin = URI.join(url, "#{d.gsub(/ +/, "_")}.git")
          say "ORIGIN: #{origin}", :red

          # Se la dir non contiene .git, allora è ancora da inizializzare
          unless File.exists? File.join(d, ".git")
            Dir.chdir d do
              run "git init"
            end
          end
          # If the template exists, then use it, otherwise, use he fallback one
          technology = d.split(File::SEPARATOR)[1]
          extension = File.exists?(File.join(Thor::Sandbox::ManageProjectsWorkingDir.source_root, "gitignore.#{technology}")) ? technology : "fallback"
          # Any dir must change the .gitignore
          template "gitignore.#{extension}", File.join(dir, d, ".gitignore")

          Dir.chdir d do
            run "git add .gitignore"
            run "git commit -a -m 'Added Gitignore'"
            run "git add . -A"
            run "git commit -a -m 'Automatic commit #{Time.now}'"
            remote_url = run "git config --get remote.origin.url", capture: true
            run "git remote #{remote_url.empty? ? "add" : "set-url"} origin #{origin}"
          end
        end
      end
    end
  end

  desc "commit_and_push anything modified under DIR", "Commit and Push anything modified under DIR"
  def commit_and_push dir
    Dir.chdir dir do
      Dir.glob("./*/*/*").each do |d|
        if File.directory? d
          Dir.chdir d do
            run "git add . -A"
            run "git commit -a -m 'Automatic commit #{Time.now} for bulk push.'"
            run "git push --set-upstream origin master"
          end
        end
      end
    end
  end

  desc "It creates a bare repos structure starting from the working DIR", "It creates a bare repos structure starting from the working DIR"
  def create_bare_repos_structure dir
    Dir.chdir dir do
      Dir.glob("./*/*/*").each do |d|
        if File.directory? d
          Dir.chdir d do
            if File.exists? ".git"
              remote_url = run "git config --get remote.origin.url", capture: true
              say remote_url, :red
              Dir.chdir ".." do
                ary = d.split(File::SEPARATOR)
                directory = ary.pop
                run "git clone --bare '#{directory}' '#{directory.gsub(/ +/, "_")}.git'"
                git_repo = File.join(Dir.home, "taris_git", *ary)
                FileUtils.mkdir_p git_repo
                FileUtils.mv File.join(Dir.pwd, "#{directory.gsub(/ +/, "_")}.git"), File.join(git_repo, "#{directory.gsub(/ +/, "_")}.git"), force: true
              end
            end
          end
        end
      end
    end
  end

  desc "This creates gems wherever the gemspec files are, then moves them from DIR into a directory", "This creates gems wherever the gemspec files are, then moves them from DIR into a directory"
  def create_gems dir
    gems_repo = File.join(Dir.home, "gems-repo")
    FileUtils.mkdir_p gems_repo
    Dir.glob(File.join(dir, "**", "*.gemspec")).each do |gspec_file|
      say "Gspec: #{gspec_file}", :red
      Dir.chdir gems_repo do
        run "gem build '#{gspec_file}'"
      end
    end
  end
end
