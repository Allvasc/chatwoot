namespace :team_visibility do
  desc 'Set a member conversation visibility. Ex: rails "team_visibility:set[1,agent@example.com,assigned_teams]"'
  task :set, %i[account_id email mode] => :environment do |_task, args|
    mode = args[:mode].presence || 'all_conversations'
    abort 'mode must be all_conversations or assigned_teams' unless AccountUser.conversation_visibilities.key?(mode)

    account = Account.find(args.fetch(:account_id))
    user = User.find_by!(email: args.fetch(:email))
    account_user = AccountUser.find_by!(account_id: account.id, user_id: user.id)
    account_user.update!(conversation_visibility: mode)

    puts "#{user.email} @ account ##{account.id} -> conversation_visibility=#{account_user.conversation_visibility}"
  end
end
