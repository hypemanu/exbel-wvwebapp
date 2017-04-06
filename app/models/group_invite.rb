class GroupInvite < ActiveRecord::Base
  belongs_to :group, inverse_of: :group_invites
  belongs_to :sender, class_name: 'User', foreign_key: :sender_id
  # belongs_to :receiver, class_name: 'User', foreign_key: :receiver_id

  enum status: {'invited': 1, 'joined': 2}

  validates :email, presence: true, format: {with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i}
  validates :name, presence: true
  validate :is_sender_a_group_member?

  after_create :send_invite_email

  def is_sender_a_group_member?
    errors.add(:sender, "Sender is not a member of the group!") unless self.group.try(:users).try(:include?, sender)
  end

  def send_invite_email
    UsersNotifier.group_invite(self).deliver_now!
  end
end
