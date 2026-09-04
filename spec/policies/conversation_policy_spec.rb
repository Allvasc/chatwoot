require 'rails_helper'

RSpec.describe ConversationPolicy, type: :policy do
  subject { described_class }

  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:administrator_context) { { user: administrator, account: account, account_user: administrator.account_users.find_by(account: account) } }
  let(:agent_context) { { user: agent, account: account, account_user: agent.account_users.find_by(account: account) } }

  let(:conversation) { create(:conversation, account: account) }

  permissions :destroy? do
    context 'when user is an administrator' do
      it 'allows destroy' do
        expect(subject).to permit(administrator_context, conversation)
      end
    end

    context 'when user is an agent' do
      it 'denies destroy' do
        expect(subject).not_to permit(agent_context, conversation)
      end
    end
  end

  permissions :index? do
    context 'when user is authenticated' do
      it 'allows index' do
        expect(subject).to permit(agent_context, conversation)
      end
    end
  end

  permissions :show? do
    context 'when user is an administrator' do
      it 'allows access' do
        expect(subject).to permit(administrator_context, conversation)
      end
    end

    context 'when agent has inbox access' do
      let(:inbox) { create(:inbox, account: account) }
      let(:conversation) { create(:conversation, account: account, inbox: inbox) }

      before { create(:inbox_member, user: agent, inbox: inbox) }

      it 'allows access' do
        expect(subject).to permit(agent_context, conversation)
      end
    end

    context 'when agent has team access' do
      let(:team) { create(:team, account: account) }
      let(:conversation) { create(:conversation, :with_team, account: account, team: team) }

      before { create(:team_member, team: team, user: agent) }

      it 'allows access' do
        expect(subject).to permit(agent_context, conversation)
      end
    end

    context 'when agent lacks inbox and team access' do
      let(:conversation) { create(:conversation, account: account) }

      it 'denies access' do
        expect(subject).not_to permit(agent_context, conversation)
      end
    end

    context 'when member has assigned_teams visibility' do
      let(:team) { create(:team, account: account) }
      let(:inbox) { create(:inbox, account: account) }

      before do
        agent.account_users.find_by(account: account).update!(conversation_visibility: :assigned_teams)
        administrator.account_users.find_by(account: account).update!(conversation_visibility: :assigned_teams)
      end

      context 'with a conversation in one of their teams' do
        let(:conversation) { create(:conversation, :with_team, account: account, team: team) }

        before { create(:team_member, team: team, user: agent) }

        it 'allows the restricted agent' do
          expect(subject).to permit(agent_context, conversation)
        end
      end

      context 'with a conversation in another team' do
        let(:conversation) { create(:conversation, :with_team, account: account) }

        it 'denies the restricted agent' do
          expect(subject).not_to permit(agent_context, conversation)
        end
      end

      context 'with a conversation not assigned to any team' do
        let(:conversation) { create(:conversation, account: account, inbox: inbox) }

        it 'allows the restricted admin' do
          expect(subject).to permit(administrator_context, conversation)
        end

        it 'allows a restricted agent who is a member of the inbox' do
          create(:inbox_member, user: agent, inbox: inbox)

          expect(subject).to permit(agent_context, conversation)
        end

        it 'denies a restricted agent outside the inbox' do
          expect(subject).not_to permit(agent_context, conversation)
        end
      end
    end
  end
end
