class PublicNotesController < ApplicationController
  allow_unauthenticated_access
  layout "public"

  # A dead share link is a normal thing for a reader to hit — the note was
  # unpublished, or the URL was mistyped — so answer with a page that says so
  # rather than the bare 404. Still a 404: the URL really holds nothing.
  rescue_from ActiveRecord::RecordNotFound, with: :note_not_found

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
    def note_not_found
      respond_to do |format|
        format.html { render :not_found, status: :not_found }
        format.md { render plain: "This note isn't available.\n", content_type: "text/markdown", status: :not_found }
      end
    end

    # Recipients of a share link don't choose their browser; skip the modern-browser gate.
    def public_page?
      true
    end
end
