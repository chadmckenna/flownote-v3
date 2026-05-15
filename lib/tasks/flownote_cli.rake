namespace :flownote_cli do
  desc "Register the first-party Flownote CLI as a Doorkeeper application"
  task register_oauth_app: :environment do
    app = Doorkeeper::Application.find_or_initialize_by(uid: "flownote-cli")
    app.update!(
      name: "Flownote CLI",
      redirect_uri: "http://127.0.0.1:53682/callback",
      confidential: false,
      scopes: "read write"
    )
    puts "Registered Flownote CLI"
    puts "  client_id: #{app.uid}"
    puts "  redirect:  #{app.redirect_uri}"
    puts "  scopes:    #{app.scopes}"
  end
end
