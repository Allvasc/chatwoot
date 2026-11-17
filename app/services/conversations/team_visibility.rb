# Team-restricted conversation visibility (account_users.conversation_visibility =
# assigned_teams) for the paths that don't go through
# Conversations::PermissionFilterService / ConversationPolicy: realtime
# broadcasts and search. Same rule: a restricted member sees conversations of
# their own teams plus conversations with no team (the shared unassigned queue).
module Conversations::TeamVisibility
  module_function

  def restricted?(account_user)
    account_user.present? && account_user.assigned_teams?
  end

  # nil stands for conversations with no team
  def visible_team_ids(user, account)
    user.teams.where(account_id: account.id).pluck(:id) + [nil]
  end

  # pubsub tokens of team-restricted members who must not receive events about
  # this conversation, because it belongs to a team they are not part of.
  def hidden_pubsub_tokens(account, conversation)
    return [] if conversation.team_id.blank?

    User.where(id: account.account_users.assigned_teams.select(:user_id))
        .where.not(id: TeamMember.where(team_id: conversation.team_id).select(:user_id))
        .pluck(:pubsub_token)
  end
end
