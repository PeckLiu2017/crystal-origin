# 已经在标准库中 load 过
# 只需要 require 就可以了
# TCPSocket represents a TCP/IP client socket.
require 'socket'
require 'http/parser'
require 'stringio'

class Crystal
  # 通过 port 号建立一个 TCPServer socket
  def initialize(port, app)
    @server = TCPServer.new(port)
    @app = app
  end

  def start
    # loop 一直保持连接
    loop do
      # 服务器端开始接受连接
      socket = @server.accept
      connection = Connection.new(socket, @app)
      connection.process
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

    # 一旦 request 被收到的回调函数
    def on_message_complete
      puts "#{@parser.http_method} #{@parser.request_path}"
      puts "   " + @parser.headers.inspect
      puts

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
end

class App
  def call(env)

    message = "Hello from the #{Process.pid}.\n"
    [
      200,
      { 'Content-Type' => 'text/plain', 'Content-Length' => message.size.to_s },
      [message]
    ]
  end
end

app = App.new
server = Crystal.new(3000, app)
puts "Plugging crystal into port 3000"
server.start
