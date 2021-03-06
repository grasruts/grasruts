# frozen_string_literal: true

class HomePickupController < ApplicationController
  before_action :authenticate_user!

  def create
    contribution = Contribution.find_by_uuid! params[:contribution_id]
    contribution.publish
    # contribution.save
    redirect_to campaign_contribution_payment_success_path(params[:campaign_id], params[:contribution_id])
  end

  def update; end
end
