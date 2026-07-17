module ConversationScoped
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
    before_action :find_conversation
  end

  private

  def find_conversation
    @conversation = current_user.conversations.find(params[:conversation_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Conversation not found' }, status: :not_found
  end
end
