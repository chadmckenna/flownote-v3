class SearchController < ApplicationController
  def index
    @query = params[:q]
    @notes = Notes::Search.new(user: Current.user, query: @query).results
  end
end
