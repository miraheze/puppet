listen {
  port = 4040
  address = "0.0.0.0"
}

namespace "nginx" {
  format = "$remote_addr - $remote_user [$time_local] \"$request\" $status $body_bytes_sent \"$http_referer\" \"$http_user_agent\" $request_time $ssl_protocol/$ssl_cipher"
  source_files = ["/var/log/nginx/access.log"]
  labels {
    app = "nginx"
    environment = "production"
  }
}
