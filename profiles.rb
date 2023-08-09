include ProfileHandling

module API
  module V1
    # API for Get user info
    class Profiles < Grape::API
      include API::V1::Auth

      post :delete_profile do
        delete_profile(current_user.profile)

        {
          status: true,
          code: 200,
          message: '',
          data: :ok
        }
      end

      get :get_customer_cards do
        cards_data = current_user.profile.profile_payment_cards
        {
          status: true,
          code: 200,
          message: '',
          data: cards_data
        }
      end

      post :add_customer_card do
        card, message = StripeCard.new(current_user.profile, params).add_card
        {
          status: true,
          code: 200,
          message: message,
          data: {card_id: card&.id}
        }
      end

      post :remove_customer_card do
        cards_data = StripeCard.new(current_user.profile, params).remove_card
        {
          status: true,
          code: 200,
          message: '',
          data: cards_data,
          card_removed: cards_data == false ? false : true
        }
      end

      post :set_default_card do
        cards_data = StripeCard.new(current_user.profile, params).default_card
        {
          status: true,
          code: 200,
          message: '',
          data: cards_data
        }
      end
    end
  end
end
