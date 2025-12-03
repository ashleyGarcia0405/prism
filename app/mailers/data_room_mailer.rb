# frozen_string_literal: true

class DataRoomMailer < ApplicationMailer
  default from: "noreply@prism-dp.com"

  def invitation_email(invitation)
    @invitation = invitation
    @data_room = invitation.data_room
    @invited_by = invitation.invited_by
    @organization = invitation.organization
    @accept_url = accept_data_room_invitation_url(token: @invitation.invitation_token)

    # Find all users of the invited organization
    admin_emails = @organization.users.pluck(:email)

    mail(
      to: admin_emails,
      subject: "You're invited to collaborate: #{@data_room.name}"
    )
  end
end