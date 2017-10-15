# 已经在标准库中 load 过
# 只需要 require 就可以了
# TCPSocket represents a TCP/IP client socket.
require 'socket'
require 'http/parser'
require 'stringio'
require 'thread'

class Crystal
  # 通过 port 号建立一个 TCPServer socket
  def initialize(port, app)
    @server = TCPServer.new(port)
    @app = app
  end

  def prefork(workers)
    workers.times do
      fork do
        puts "Forked #{Process.pid}"
        start
      end
    end
    Process.waitall
  end

  def start
    # loop 一直保持连接
    loop do
      # 服务器端开始接受连接
      socket = @server.accept
      Thread.new do
        connection = Connection.new(socket, @app)
        connection.process
      end
      # 返回响应之后连接会断开
      # 要保持连接用 loop 块
    end
  end

  class Connection
    def initialize(socket, app)
      @socket = socket
      @app = app
      @parser = Http::Parser.new(self)
    end

    def process
      # read 1024 bytes
      # 但数据有比 1024 bytes 多的情况
      # 所以保持连接并读数据直到连接关闭或没有数据为止
      until @socket.closed? || @socket.eof?
        data = @socket.readpartial(1024)
        @parser << data
      end
    end

    # 一旦 request 被收到执行回调函数
    def on_message_complete
      # puts "#{@parser.http_method} #{@parser.request_path}"
      # puts "   " + @parser.headers.inspect
      # puts

      env = {}
      @parser.headers.each do |name, value|
        name = "HTTP_" + name.upcase.tr("_","-")
        env[name] = value
      end
      env["PATH_INFO"] = @parser.request_path
      env["REQUEST_METHOD"] = @parser.http_method
      env["rack.input"] = StringIO.new
      send_response env
    end

    REASONS = {
      200 => "OK",
      404 => "NOT FOUND"
    }
    # 因为可能有 another one？
    def send_response(env)
      status, headers, body = @app.call(env)
      reason = REASONS[status]
      # "\r\n" 一般一起用，表示键盘上的回车键
      @socket.write "HTTP/1.1 #{status} #{reason}\r\n"
      headers.each_pair do |name, value|
        @socket.write "#{name}: #{value}\r\n"
      end
      @socket.write "\r\n"
      body.each do |chunk|
        @socket.write chunk
      end

      body.close if body.respond_to? :close

      close
    end

    def close
      @socket.close
    end
  end

  # 重构 class App
  class Builder
    attr_reader :app

    def run(app)
      @app = app
    end

    def self.parse_file(file)
      content = File.read(file)
      builder = self.new
      # 从这里开始执行 file 中的程序
      # 运行 run 方法
      builder.instance_eval(content)
      builder.app
    end
  end

end

app = Crystal::Builder.parse_file('config.ru')
server = Crystal.new(3000, app)
puts "Plugging crystal into port 3000"
# server.start
server.prefork(3)
