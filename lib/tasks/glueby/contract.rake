
namespace :glueby do
  namespace :contract do
    desc 'initialize glueby contract config'
    task :install, [] => [:environment] do |_, _|
      Rails::Generators.invoke("glueby:contract:initializer")
    end
  end
end
