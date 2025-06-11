# frozen_string_literal: true

require "bundler/setup"
Bundler.require(:default)

configure :production, :development do
  DB = Sequel.sqlite("db/test.db", logger: Logger.new($stdout))
end

configure :test do
  Sequel.extension :migration
  DB = Sequel.sqlite(":memory:", logger: Logger.new($stdout))
  Sequel::Migrator.run(DB, "./db/migrations", use_transactions: false)
end

Dir["models/*.rb"].each { |path| require_relative path.to_s }
Dir["business_operations/*.rb"].each { |path| require_relative path.to_s }

get "/" do
  "OK"
end

post "/operation" do
  request.body.rewind
  data = JSON.parse(request.body.read)

  current_user = User.with_pk!(data["user_id"])
  result = CalculateOperation.new(current_user).call(data["positions"])

  yajl :operation, locals: { user: current_user, result: result }
end

post "/submit" do
  request.body.rewind
  data = JSON.parse request.body.read

  current_user = User.with_pk!(data["user"]["id"])
  operation = SubmitOperation.new(current_user).call(data["operation_id"], data["write_off"])

  yajl :submit, locals: { user: current_user, operation: operation }
end
