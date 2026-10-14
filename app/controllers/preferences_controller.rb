# Settings on the profile page. Unlike the rest of it, no current password: a
# preference changes how the app behaves for you, not who can get in.
class PreferencesController < ApplicationController
  def update
    if Current.user.update(params.expect(user: [ :open_notes_in ]))
      redirect_to profile_path, notice: "Preferences saved."
    else
      redirect_to profile_path, alert: Current.user.errors.full_messages.to_sentence
    end
  end
end
