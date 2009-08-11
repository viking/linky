require 'logger'

module Linky
  module Databases
    class Worker
      DRB_URI = "druby://localhost:9786"
      LOGFILE = File.expand_path(File.join(File.dirname(__FILE__),'..','..','..','log','worker.log'))

      def initialize
        @log = Logger.new(STDERR)
      end

      def uri
        return DRB_URI
      end

      def remote_query(options)
        Thread.new do
          @log.info "Options: " + options.inspect

          session_id = options[:session_id]
          local = Databases::Local.new
          remote = Databases::Remote.new(options[:db])
          local.transaction do |ldbh|
            query, total, label_length, value_length = ldbh.select_one("SELECT query, total, label_length, value_length FROM sessions WHERE id = ?", session_id)
            total = total.to_i
            label_length = label_length ? label_length.to_i : 0
            value_length = value_length ? value_length.to_i : 0

            @log.info "Query:"
            @log.info query

            lsth = ldbh.prepare(<<-EOF)
              INSERT INTO records (record_id, name, value, target_id, session_id)
              VALUES(?, ?, ?, ?, #{session_id})
            EOF

            result = remote.session do |rdbh|
              rsth = rdbh.prepare(query)
              rsth.execute(total)

              # find column ranges; save max name length
              names = {:a => [], :b => []}
              num_cols = rsth.column_names.size
              rsth.column_names.each_with_index do |col, i|
                first_b ||= i   if col =~ /^B/
                label_length = col.length  if col.length > label_length

                names[col =~ /^A_/ ? :a : :b] << col[2..-1]
              end
              tmp = names[:a].length
              ranges = {:a => 0..(tmp-1), :b => tmp..(num_cols-1)}

              target_id = first_id = candidate_id = nil

              # collect each target and its candidates
              set = []
              loop do
                row = rsth.fetch
                if row.nil? || target_id != row["A_id"]
                  # insert all rows from the previous set
                  set.each { |record| lsth.execute(*record) }
                  set.clear
                  break if row.nil?

                  row[ranges[:a]].each_with_index do |value, i|
                    next  if value.nil?
                    if i == 0
                      target_id = value
                      next
                    end
                    set << [target_id, names[:a][i], value, nil]
                    value_length = value.length   if value.length > value_length
                  end
                  first_id ||= target_id
                end

                row[ranges[:b]].each_with_index do |value, i|
                  next  if value.nil?
                  if i == 0
                    candidate_id = value
                    next
                  end
                  set << [candidate_id, names[:b][i], value, target_id]
                end
                total += 1
              end

              qry = [
                "UPDATE sessions SET status = ?, first_id = ?, last_id = ?, total = ?, done = ?, label_length = ?, value_length = ? WHERE id = ?",
                'done', first_id, target_id, total, (total % options[:limit]) > 0, label_length, value_length, session_id
              ]
              @log.info "Updating session: #{qry.inspect}"
              ldbh.do(*qry)
              rsth.finish
            end
            lsth.finish

            if result.is_a?(Exception)
              ldbh.do(
                "UPDATE sessions SET status = ?, exception = ? WHERE id = ?",
                'error', Marshal.dump(result), session_id
              )
            end
          end
          @log.info "Finished query."
        end
      end
    end
  end
end
