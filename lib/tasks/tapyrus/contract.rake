
namespace :tapyrus do
  namespace :contract do
    desc 'initialize tapyrus contract config'
    task :install, [] => [:environment] do |_, _|
      Rails::Generators.invoke("tapyrus:contract:initializer")
    end
  end
end
