class Api::V1::Accounts::Conversations::AssignmentsController < Api::V1::Accounts::Conversations::BaseController
  # assign agent to a conversation
  def create
    # if params[:assignee_id] is not a valid id, it will set to nil, hence unassigning the conversation
    assignee = Current.account.users.find_by(id: params[:assignee_id])
    
    @agents ||= Current.account.users.order_by_full_name
    
    if assignee != nil && assignee.account_users.first["limits"] != nil
      # Get the offset of current agent in agents list
      @index = @agents.pluck(:id).index(assignee["id"])
      Rails.logger.info "Assignment Offset: #{@index}"
      
      # Check if assignment of agent is valid
      assignment_maximum = 0
      assignment_maximum = assignee.account_users.first["limits"] unless assignee.account_users.first["limits"] == nil
      Rails.logger.info "Assignment Maximum Limits: #{assignment_maximum}"
      
      conversation_count = ::Conversation.where(assignee_id: params[:assignee_id]).length
      Rails.logger.info "Assignment Conversation Count: #{conversation_count}"
      
      unless assignment_maximum > conversation_count
        Rails.logger.info "Assignment ID: #{assignee['id']}"
        Rails.logger.info "NEXT AGENT ASSIGNMENT"
        assignee = assignee_next(assignment_maximum: assignment_maximum, conversation_count: conversation_count, assignee: assignee, index: @index)
      end
    end
    
    @conversation.update_assignee(assignee)
    render json: assignee
  end
  
  def assignee_next(assignment_maximum:, conversation_count:, assignee:, index:)
    # Get the next index offset of agents list ordered by full name(@agents)
    if index == @agents.size - 1
      next_index = 0
    else
      next_index = index + 1
    end
    
    # Return nil when @agents are cycled fully
    if index == @index - 1 || index == -1
      Rails.logger.info "Conversation limits overflow, index: #{index}"
      return nil
    end
    
    next_assignee = @agents.offset(next_index).first
    Rails.logger.info "NEXT ASSIGNMENT ID: #{next_assignee["id"]}"
    next_assignment_maximum = next_assignee.account_users.first["limits"]
    Rails.logger.info "Next Assignment Limits: #{next_assignment_maximum}"
    next_conversation_count = ::Conversation.where(assignee_id: next_assignee["id"]).length
    Rails.logger.info "Next Conversation Count: #{next_conversation_count}"
    
    # If next agent is admin, return.
    return next_assignee if next_assignment_maximum == nil
    # If next agent is not reached out maximum, return.
    return next_assignee if next_assignment_maximum > next_conversation_count
    assignee_next(assignment_maximum: next_assignment_maximum, conversation_count: next_conversation_count, assignee: next_assignee, index: next_index) unless assignment_maximum > conversation_count
  end
  
end
