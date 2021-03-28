# module ApplicationCable
#   class Connection < ActionCable::Connection::Base
#     identified_by :current_user

#     def connect
#       self.current_user = find_verified_user
#     end

#     private

#     # Some subscriptions may be public, so we will leave it to the authorization service to decide whether particular channels can be subscribed to
#     # td: generalize so it's possible to use something other than Warden / Devise
#     def find_verified_user
#       env['warden'].user
#     end
#   end
# end
