module MysqlIndexChecker
  class IndexVerifier
    IGNORED_SQL = [
      /^PRAGMA (?!(table_info))/,
      /^SELECT currval/,
      /^SELECT CAST/,
      /^SELECT @@IDENTITY/,
      /^SELECT @@ROWCOUNT/,
      /^SAVEPOINT/,
      /^ROLLBACK TO SAVEPOINT/,
      /^RELEASE SAVEPOINT/,
      /^SHOW max_identifier_length/,
      /^SELECT @@FOREIGN_KEY_CHECKS/,
      /^SET FOREIGN_KEY_CHECKS/,
      /^TRUNCATE TABLE/
    ].freeze

    attr_reader :queries_missing_index

    def initialize
      @queries_missing_index = []
    end

    def call(_name, _start, _finish, _message_id, values)
      # FIXME: this seems bad. we should probably have a better way to indicate
      # the query was cached
      if values[:name] != "CACHE" &&
         values[:name] != "SCHEMA" &&
         values[:name].present? &&
         values[:sql].downcase.include?("where") &&
         IGNORED_SQL.none? { |r| values[:sql] =~ r }

        # more details about the result https://dev.mysql.com/doc/refman/8.0/en/explain-output.html
        result = ActiveRecord::Base.connection.query("explain #{values[:sql]}").first

        return if result.last&.include?("no matching row")

        @queries_missing_index << values[:sql] unless result[6]
      end
    end
  end
end
