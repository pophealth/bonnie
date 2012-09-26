
connection  = Mongo::Connection.new
MONGO_DB = connection[Mongoid.default_session.options[:database]]

module QME
  module DatabaseAccess
    # Monkey patch in the connection for the application
    def get_db
      MONGO_DB
    end
  end
end