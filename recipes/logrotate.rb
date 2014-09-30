logrotate_app 'redmine' do
  cookbook  'logrotate'
  path      ["#{node['redmine']['deploy_to']}/shared/*.log"]
  frequency 'daily'
  rotate    7
  options ["xxx"]
  copytruncate
end