logrotate_app 'redmine' do
  cookbook  'logrotate'
  path      ["#{node['redmine']['deploy_to']}/shared/log/*.log"]
  frequency 'daily'
  rotate    30
  options ["copytruncate", "compress", "delaycompress", "notifempty", "dateext"]
end
