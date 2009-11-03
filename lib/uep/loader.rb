class UEP::Loader
  
  def initialize(app, options = {})
    @app = app
    instance_eval(&block) if block_given?
  end
  def call(env)
    @env = env.dup
    @start_time = Time.now.to_f
    # experiment, remove leading /status 
    if newpath = env['REQUEST_URI'][/^\/status(\/.*$)/,1]
      @env.merge! 'PATH_INFO' => newpath, 'REQUEST_PATH' => newpath,'REQUEST_URI' => newpath      
    end
    @request = Rack::Request.new @env
    if @request.path =~ /^\/uep\//
      # Read payload
      path, start, finish = undump
      puts "Page: #{path}" 
      t = Time.now.to_f
      puts "   processing: #{'%6.3f' % (finish - start)}"
      puts "    rendering: #{'%6.3f' % (t - finish)}"
      puts "        total: #{'%6.3f' % (t - start)}"
      Rack::Response.new([0], 200, {}).finish
    else
      # Add payload
      status, headers, body = @app.call(@env)
      parts = []
      found = false
      len = 0
      body.each do |s|
        if !found && s.is_a?(String) && body_match = s.match(/<\/body>/i) 
          found = true
          parts << body_match.pre_match
          parts << payload
          parts << body_match.to_s
          parts << body_match.post_match
        else
          parts << s
        end
        len += parts.last.size
      end
      puts "len: #{headers['CONTENT_LENGTH']}"
      if found
        #dump_request
        headers['CONTENT_LENGTH'] &&= len
        Rack::Response.new(parts, status, headers).finish
      else
        return [status, headers, body]
      end
    end
  end
  
  def payload
    @payload ||= %Q[<img width=1 height=1 src="/uep#{@request.path}/#{@start_time}:#{Time.now.to_f}.png">]
  end
  def undump
    info = @request.path[/\/uep\/(.*)\.png/, 1]
    info.match /^(.*)\/([\d.]*):([\d.]*)$/
    r = [$1, $2.to_f, $3.to_f]
    puts r.inspect
    r
  end
  
  def dump_request
    body = StringIO.new
    body.puts "ip\t#{@request.ip}"
    body.puts "host\t#{@request.host}"
    body.puts "path\t#{@request.url}"
    body.puts "query\t#{@request.query_string}"
    body.puts "params\t#{@request.params.inspect}"
    body.puts ""
    if @response
      body.puts "<h2>Response Headers</h2>"
      body.puts @response.header.to_a.map{|k,v| "#{'%22s' % k} = #{v.to_s[0..60]}" }.join("\n")
    end
    body.puts "\n\nComplete ENV:"
    body.puts @env.to_a.map{|k,v| "#{'%22s' % k} = #{v.to_s[0..60]}" }.join("\n")
    puts body.string
  end
end