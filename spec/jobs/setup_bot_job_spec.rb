require 'spec_helper'

describe SetupBotJob do
  let!(:bi) { create :bot_instance }

  describe '#perform' do
    context 'slack' do
      before { bi.update_attribute(:provider, 'slack') }

      context 'when token is valid' do
        before do
          stub_request(:get, "https://slack.com/api/auth.test?token=#{bi.token}").
            to_return(status: 200, body: { ok: true, url: "https://myteam.slack.com/", team: "My Team", user: "cal", team_id: "T12345", user_id: "U12345"}.to_json)
          stub_request(:get, "https://slack.com/api/users.list?token=#{bi.token}").
            to_return(status: 200, body:
            {
              "ok" => true,
              "members" => [
                {
                  'id' => 'UDEADBEEF1',
                  'name' => 'sjobs',
                  'tz' => 'Los Angeles',
                  'tz_label' => 'Pacific Daylight Time',
                  'tz_offset' => '-25200',
                  'profile' => {
                    'email' => 'sjobs@apple.com',
                    'first_name' => 'Steve',
                    'last_name' => 'Jobs',
                    'real_name' => 'Steve Jobs',
                  },
                  'is_admin' => true,
                  'is_owner' => true,
                  'is_restricted' => false
                },
                {
                  'id' => 'UDEADBEEF2',
                  'name' => 'elonmusk',
                  'profile' => {
                    'email' => 'elon@apple.com',
                    'first_name' => 'Elon',
                    'last_name' => 'Musk',
                    'real_name' => 'Elon Musk',
                  },
                  'tz' => 'Los Angeles',
                  'tz_label' => 'Pacific Daylight Time',
                  'tz_offset' => '-25200',
                  'is_admin' => false,
                  'is_owner' => false,
                  'is_restricted' => true
                },
                {
                  'id' => 'UDEADBEEF3',
                  'name' => 'timcook',
                  'profile' => {
                    'email' => 'tim@apple.com',
                    'first_name' => 'Tim',
                    'last_name' => 'Cook',
                    'real_name' => 'Tim Cook',
                  },
                  'tz' => 'Los Angeles',
                  'tz_label' => 'Pacific Daylight Time',
                  'tz_offset' => '-25200',
                  'is_admin' => true,
                  'is_owner' => false,
                  'is_restricted' => false,
                  'deleted' => true
                },
              ]
            }.to_json
          )
        end

        it 'should enable the bot and setup team_id, team_name and team_url' do
          SetupBotJob.new.perform(bi.id)
          bi.reload
          expect(bi.state).to eql 'enabled'
          expect(bi.uid).to eql 'U12345'
          expect(bi.instance_attributes['team_id']).to eql 'T12345'
          expect(bi.instance_attributes['team_name']).to eql 'My Team'
          expect(bi.instance_attributes['team_url']).to eql 'https://myteam.slack.com/'
        end

        context 'none of the users exist' do
          it 'should add three users' do
            expect {
              SetupBotJob.new.perform(bi.id)
              bi.reload
            }.to change(bi.users, :count).by(3)

            members = bi.users.order("id ASC")

            user1 = members[0]

            expect(user1.user_attributes['timezone']).to eql 'Los Angeles'
            expect(user1.user_attributes['timezone_description']).to eql 'Pacific Daylight Time'
            expect(user1.user_attributes['timezone_offset']).to eql -25200
            expect(user1.user_attributes['nickname']).to eql 'sjobs'
            expect(user1.user_attributes['email']).to eql 'sjobs@apple.com'
            expect(user1.user_attributes['first_name']).to eql 'Steve'
            expect(user1.user_attributes['last_name']).to eql 'Jobs'
            expect(user1.user_attributes['full_name']).to eql 'Steve Jobs'
            expect(user1.membership_type).to eql 'owner'
            expect(user1.uid).to eql 'UDEADBEEF1'

            user2 = members[1]

            expect(user2.user_attributes['timezone']).to eql 'Los Angeles'
            expect(user2.user_attributes['timezone_description']).to eql 'Pacific Daylight Time'
            expect(user2.user_attributes['timezone_offset']).to eql -25200
            expect(user2.user_attributes['nickname']).to eql 'elonmusk'
            expect(user2.user_attributes['email']).to eql 'elon@apple.com'
            expect(user2.user_attributes['first_name']).to eql 'Elon'
            expect(user2.user_attributes['last_name']).to eql 'Musk'
            expect(user2.user_attributes['full_name']).to eql 'Elon Musk'
            expect(user2.membership_type).to eql 'guest'
            expect(user2.uid).to eql 'UDEADBEEF2'

            user3 = members[2]

            expect(user3.user_attributes['timezone']).to eql 'Los Angeles'
            expect(user3.user_attributes['timezone_description']).to eql 'Pacific Daylight Time'
            expect(user3.user_attributes['timezone_offset']).to eql -25200
            expect(user3.user_attributes['nickname']).to eql 'timcook'
            expect(user3.user_attributes['email']).to eql 'tim@apple.com'
            expect(user3.user_attributes['first_name']).to eql 'Tim'
            expect(user3.user_attributes['last_name']).to eql 'Cook'
            expect(user3.user_attributes['full_name']).to eql 'Tim Cook'
            expect(user3.membership_type).to eql 'deleted'
            expect(user3.uid).to eql 'UDEADBEEF3'
          end
        end

        context 'some of the users exist' do
          let!(:existing_user) { create :bot_user, bot_instance: bi, uid: 'UDEADBEEF2', user_attributes: { email: 'elonmusk@apple.com' }, membership_type: 'member' }

          it 'should only add the new users and update info on existing users' do
            expect {
              SetupBotJob.new.perform(bi.id)
              bi.reload
            }.to change(bi.users, :count).by(2)

            members = bi.users.order("id ASC")

            user1 = members[0]
            expect(user1.user_attributes['timezone']).to eql 'Los Angeles'
            expect(user1.user_attributes['timezone_description']).to eql 'Pacific Daylight Time'
            expect(user1.user_attributes['timezone_offset']).to eql -25200
            expect(user1.user_attributes['nickname']).to eql 'elonmusk'
            expect(user1.user_attributes['email']).to eql 'elon@apple.com'
            expect(user1.user_attributes['first_name']).to eql 'Elon'
            expect(user1.user_attributes['last_name']).to eql 'Musk'
            expect(user1.user_attributes['full_name']).to eql 'Elon Musk'
            expect(user1.membership_type).to eql 'guest'
            expect(user1.uid).to eql 'UDEADBEEF2'

            user2 = members[1]
            expect(user2.user_attributes['timezone']).to eql 'Los Angeles'
            expect(user2.user_attributes['timezone_description']).to eql 'Pacific Daylight Time'
            expect(user2.user_attributes['timezone_offset']).to eql -25200
            expect(user2.user_attributes['nickname']).to eql 'sjobs'
            expect(user2.user_attributes['email']).to eql 'sjobs@apple.com'
            expect(user2.user_attributes['first_name']).to eql 'Steve'
            expect(user2.user_attributes['last_name']).to eql 'Jobs'
            expect(user2.user_attributes['full_name']).to eql 'Steve Jobs'
            expect(user2.membership_type).to eql 'owner'
            expect(user2.uid).to eql 'UDEADBEEF1'

            user3 = members[2]
            expect(user3.user_attributes['timezone']).to eql 'Los Angeles'
            expect(user3.user_attributes['timezone_description']).to eql 'Pacific Daylight Time'
            expect(user3.user_attributes['timezone_offset']).to eql -25200
            expect(user3.user_attributes['nickname']).to eql 'timcook'
            expect(user3.user_attributes['email']).to eql 'tim@apple.com'
            expect(user3.user_attributes['first_name']).to eql 'Tim'
            expect(user3.user_attributes['last_name']).to eql 'Cook'
            expect(user3.user_attributes['full_name']).to eql 'Tim Cook'
            expect(user3.membership_type).to eql 'deleted'
            expect(user3.uid).to eql 'UDEADBEEF3'
          end
        end
      end

      context 'when token is invalid' do
        before do
          stub_request(:get, "https://slack.com/api/auth.test?token=#{bi.token}").
                    to_return(status: 200, body: { ok: false, error: "account_inactive" }.to_json)
        end

        it 'should enable the bot and setup team_id, team_name and team_url' do
          SetupBotJob.new.perform(bi.id)
          bi.reload
          expect(bi.state).to eql 'pending'
          expect(bi.uid).to be_nil
          expect(bi.instance_attributes).to eql({})
        end
      end
    end
  end
end