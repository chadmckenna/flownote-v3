class SearchController < ApplicationController
  def index
    @query = params[:q]

    # An empty box offers the notes you've just been in, so the modal is a way
    # back to recent work as well as a search. Typing anything switches to search.
    if @query.blank?
      @recent = recent_notes
    else
      @notes = Notes::Search.new(user: Current.user, query: @query).results
    end
  end
end
