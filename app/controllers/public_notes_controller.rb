class PublicNotesController < ApplicationController
  allow_unauthenticated_access
  layout "public"

  # An unpublished, missing, or wrong-owner note all raise RecordNotFound, so a
  # 404 never distinguishes "never existed" from "no longer shared".
  def show
    @note = Note.published.joins(:user).where(users: { username: params[:username] }).find_by!(slug: params[:slug])

    respond_to do |format|
      format.html
      format.md { render plain: @note.body.to_s, content_type: "text/markdown" }
    end
  end

  private
    # Recipients of a share link don't choose their browser; skip the modern-browser gate.
    def public_page?
      true
    end
end
