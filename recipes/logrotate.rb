logrotate_app 'redmine' do
  cookbook  'logrotate'
  path      ["#{node['redmine']['deploy_to']}/shared/log/*.log"]
  frequency 'weekly'
  rotate    12
  options ["copytruncate"]
end
