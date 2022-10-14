

# Class for Docker container to run MySQL specific test cases
class MySQLContainer
  include Singleton

  MYSQL_VERSION = "8.0"
  MYSQL_CONTAINER_NAME = "db"

  class << self
    extend Forwardable
    delegate %i[setup start stop teardown config] => :instance
  end

  attr_reader :container

  def config
    @config ||= {
      adapter: 'mysql2',
      database: 'glueby_test',
      encoding: 'utf8mb4',
      pool: 40,
      username: 'root',
      password: 'password',
      host: '127.0.0.1'
    }
  end

  def setup
    begin
      Docker::Image.get("mysql:#{MYSQL_VERSION}")
    rescue Docker::Error::NotFoundError => e
      Docker::Image.create(fromImage: "mysql:#{MYSQL_VERSION}")
    end

    @container = Docker::Container.create({
      name: MYSQL_CONTAINER_NAME,
      "Image" => "mysql:#{MYSQL_VERSION}",
      "Env" => [
        "MYSQL_ROOT_PASSWORD=password"
      ],
      "HostConfig" => {
        "PortBindings" => { "3306/tcp" => [{ "HostIp" => "", "HostPort" => "3306" }] },
      }
    })
  end

  def start
    container.start!

    wait_for_connecting
  end

  def wait_for_connecting
    sleep(1)
    ::ActiveRecord::Base.establish_connection(config)
    connection = ::ActiveRecord::Base.connection
  rescue ActiveRecord::NoDatabaseError => e
    client = Mysql2::Client.new(
      :host => config[:host],
      :username => config[:username],
      :password => config[:password]
    )
    client.query("CREATE DATABASE #{config[:database]}")
    client.query("USE #{config[:database]}")
    retry
  rescue => e
    puts e
    retry
  end

  def stop
    container.stop!
  end

  def teardown
    container = Docker::Container.get(MYSQL_CONTAINER_NAME)
    container.stop!
    container.remove
  end
end
