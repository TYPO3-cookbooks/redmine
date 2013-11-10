# Add cron job to fetch changesets
cron 'fetch_changesets' do
  if node['redmine']['cron_fetch_changesets'].nil? || node['redmine']['cron_fetch_changesets'] == false
    action :delete
  else
    minute node['redmine']['cron_fetch_changesets']['minute']
    hour   node['redmine']['cron_fetch_changesets']['hour']
  end

  command "BUNDLE_GEMFILE=#{node['redmine']['deploy_to']}/current/Gemfile RAILS_ENV=production bundle exec rake -f #{node['redmine']['deploy_to']}/current/Rakefile redmine:fetch_changesets"
  user 'redmine'
end
