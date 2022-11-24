defmodule CouchDBEx do

  @moduledoc """
  Main entrypoint to the `CouchDBEx` API.

  ## Authentification

  This module supports both basic and cookie authentification
  with automatic cookie renewal.

  To use authentification, you'll need to pass the `username` and `password`
  parameters at the module start and set `auth_method` to either
  `:cookie` or `:basic`, you also can just not provide any of those, then there
  will not be any authentification going on.

  Basic authentifcation will pass the `Authrorization` header with every request you make,
  this header will contain base64 encoded login and password, be aware that is is **insecure**.

  The other method is more secure: when the worker starts, it will initiate a session with
  the database and use the cookie it provides until the `:cookie_session_minutes`
  timout (9 minutes by default, since CouchDB sessions time out in 10 minutes with the
  default database configuration). When the cookie times out, it will be renewed automatically
  by the internal auth agent; you probably want to set this option one minute less
  than the actual database configuration just to be safe.

  You can read more about authentification [here](http://docs.couchdb.org/en/latest/api/server/authn.html)

  ## Examples

  Example module specification for the supervisor:

      children = [
          {CouchDBEx.Worker, [
              hostname: "http://localhost",
              username: "couchdb",
              password: "couchdb",
              auth_method: :cookie,
              cookie_session_minutes: 9
            ]}
        ]

      opts = [strategy: :one_for_one, name: CouchDBEx.Test.Supervisor]
      Supervisor.start_link(children, opts)
  """

  @type couchdb_res :: {:ok, map} | {:error, %CouchDBEx.Error{} | term}

  @doc """
  Queries the CouchDB server for some general information
  about it (e.g. version)
  """
  @spec couchdb_info :: couchdb_res
  def couchdb_info, do: GenServer.call(CouchDBEx.Worker, :couchdb_info)


  ## Databases


  @doc """
  Checks if the specified database exists
  """
  @spec db_exists?(db_name :: String.t) :: {:ok, boolean} | {:error, term}
  def db_exists?(db_name), do: GenServer.call(CouchDBEx.Worker, {:db_exists?, db_name})

  @doc """
  Get some general information about the database, this includes it's name,
  size and clustering information.
  """
  @spec db_info(db_name :: String.t) :: couchdb_res
  def db_info(db_name), do: GenServer.call(CouchDBEx.Worker, {:db_info, db_name})

  @doc """
  Create a new database.

  The database name must be composed by following next rules:

  * Name must begin with a lowercase letter (`a-z`)
  * Lowercase characters (`a-z`)
  * Digits (`0-9`)
  * Any of the characters `_`, `$`, `(`, `)`, `+`, `-`, and `/`.

  ## Options

  * `shards` - number of shards for this database, defaults to 8
  """
  @spec db_create(db_name :: String.t, opts :: keyword) :: :ok | {:error, term}
  def db_create(db_name, opts \\ []), do: GenServer.call(CouchDBEx.Worker, {:db_create, db_name, opts})

  @doc """
  Deletes the specified database, and all the documents and attachments contained within it.
  """
  @spec db_delete(db_name :: String.t) :: :ok | {:error, term}
  def db_delete(db_name), do: GenServer.call(CouchDBEx.Worker, {:db_delete, db_name})

  @doc """
  Request compaction of the specified database.

  If you want to know more, read [here](http://docs.couchdb.org/en/2.1.1/api/database/compact.html)
  """
  @spec db_compact(db_name :: String.t) :: :ok | {:error, term}
  def db_compact(db_name), do: GenServer.call(CouchDBEx.Worker, {:db_compact, db_name})

  @doc """
  Get the list of all databases, this list includes system databases like `_users`
  """
  @spec db_list :: {:ok, [String.t]} | {:error, term}
  def db_list, do: GenServer.call(CouchDBEx.Worker, {:db_list})


  ## UUIDs


  @doc """
  Get a single UUID from the server
  """
  @spec uuid_get :: {:ok, String.t} | {:error, term}
  def uuid_get, do: GenServer.call(CouchDBEx.Worker, {:uuid_get})

  @doc """
  Get several UUIDs from the server
  """
  @spec uuid_get(n :: integer) :: {:ok, [String.t]} | {:error, term}
  def uuid_get(n), do: GenServer.call(CouchDBEx.Worker, {:uuid_get, n})


  ## Documents

  @doc """
  Insert or update a single document, for multiple documents see `CouchDBEx.document_insert_many/2`.
  """
  @spec document_insert_one(doc :: map, db :: String.t) :: couchdb_res
  def document_insert_one(doc, db), do: GenServer.call(CouchDBEx.Worker, {:document_insert, doc, db})

  @doc """
  Insert or update multiple documents, for a single document see `CouchDBEx.document_insert_one/2`.

  Internally, this function will make a request to
  [`_bulk_docs`](http://docs.couchdb.org/en/2.1.1/api/database/bulk-api.html#db-bulk-docs), that makes
  it suitable for mass updates too
  """
  @spec document_insert_many(docs :: [map], db :: String.t) :: {:ok, [map]} | {:error, term}
  def document_insert_many(docs, db) do
    GenServer.call(CouchDBEx.Worker, {:document_insert, docs, db}, :infinity)
  end

  @doc """
  Lists all (or filtered) documents in the database, along with their number

  Options are those from
  [`_all_docs`](http://docs.couchdb.org/en/2.1.1/api/database/bulk-api.html#get--db-_all_docs)
  """
  @spec document_list(db :: String.t, opts :: keyword) :: couchdb_res
  def document_list(db, opts \\ []), do: GenServer.call(CouchDBEx.Worker, {:document_list, db, opts}, :infinity)

  @doc """
  Bulk fetch changes in the database, along with their number

  Options are those from
  [`_changes`](http://docs.couchdb.org/en/2.1.1/api/database/bulk-api.html#get--db-_all_docs)
  """
  @spec document_changes(db :: String.t, opts :: keyword) :: couchdb_res
  def document_changes(db, opts \\ [style: "all_docs", feed: "normal"]), do: GenServer.call(CouchDBEx.Worker, {:document_changes, db, opts}, :infinity)

  @doc """
  Bulk fetch revs (or filtered) documents in the database, along with their number

  Options are those from
  [`_bulk_docs`](http://docs.couchdb.org/en/2.1.1/api/database/bulk-api.html#get--db-_all_docs)
  """
  @spec document_revs(revs :: map, db :: String.t, opts :: keyword) :: couchdb_res
  def document_revs(revs, db, opts \\ [revs: true, latest: true]), do: GenServer.call(CouchDBEx.Worker, {:document_revs, revs, db, opts}, :infinity)

  @doc """
  Rev diffs of documents in the database

  Options are those from
  [`_revs_diff`](http://docs.couchdb.org/en/2.1.1/api/database/bulk-api.html#get--db-_all_docs)
  """
  @spec document_rev_diffs(revs :: map, db :: String.t, opts :: keyword) :: couchdb_res
  def document_rev_diffs(revs, db, opts \\ []), do: GenServer.call(CouchDBEx.Worker, {:document_rev_diffs, revs, db, opts}, :infinity)

  @doc """
  Bulk update documents in the database, along with their number

  Options are those from
  [`_bulk_docs`](http://docs.couchdb.org/en/2.1.1/api/database/bulk-api.html#get--db-_all_docs)
  """
  @spec document_bulk_update(docs :: [map], db :: String.t, opts :: keyword) :: couchdb_res
  def document_bulk_update(docs, db, opts \\ []), do: GenServer.call(CouchDBEx.Worker, {:document_bulk_update, docs, db, opts}, :infinity)

  @doc """
  Get a document from the database.

  ## Options

  * `attachments` - should the request return full information about attachments
                    (includes full base64 encoded attachments into the request), `false` by default
  """
  @spec document_get(id :: String.t, db :: String.t, opts :: keyword) :: couchdb_res
  def document_get(id, db, opts \\ []), do: GenServer.call(CouchDBEx.Worker, {:document_get, id, db, opts})

  @doc """
  Find a document in the database using the
  [selector spec](http://docs.couchdb.org/en/2.1.1/api/database/find.html#find-selectors).

  ## Options

  Options and their description are can be found [here](http://docs.couchdb.org/en/2.1.1/api/database/find.html)
  """
  @spec document_find(selector :: map, db :: String.t, opts :: keyword) :: couchdb_res
  def document_find(selector, db, opts \\ []) do
    GenServer.call(CouchDBEx.Worker, {:document_find, selector, db, opts}, :infinity)
  end

  @doc """
  Delete a single document from the database.
  """
  @spec document_delete_one(id :: String.t, rev :: String.t, db :: String.t) :: :ok | {:error, term}
  def document_delete_one(id, rev, db), do: GenServer.call(CouchDBEx.Worker, {:document_delete, {id, rev}, db})

  @doc """
  Delete multiple documents from the database, `id_rev` is an array of documents' `{id, revision}`.

  Internally, this function asks `_bulk_docs` to set `_deleted` for those documents
  """
  @spec document_delete_many(id_rev :: [{String.t, String.t}], db :: String.t) :: couchdb_res
  def document_delete_many(id_rev, db) do
    GenServer.call(CouchDBEx.Worker, {:document_delete, id_rev, db}, :infinity)
  end


  ## Attachments


  @doc """
  Upload an attachment to the document.

  `id` is the document id to which the attachment will be added, `name` is the
  attacument's name, `bindata` is binary data which will be uploaded (essentialy, anything that
  satisfies the `is_binary/1` constraint), `doc_rev` is current document revision.

  This function returns new document revision, as well as the document id.

  ## Options

  * `content_type` - content type of the attachment in the standard format (e.g. `text/plain`),
                     this option will set the `Content-Type` header for the request.
  """
  @spec attachment_upload(
    db :: String.t, id :: String.t, doc_rev :: String.t, name :: String.t, bindata :: binary, opts :: keyword
  ) :: {:ok, [id: String.t, rev: String.t]} | {:error, term}
  def attachment_upload(db, id, doc_rev, name, bindata, opts \\ []) do
    GenServer.call(CouchDBEx.Worker, {:attachment_upload, db, id, doc_rev, {name, bindata}, opts}, :infinity)
  end

  @doc """
  Get an attachment from a document.

  This function will allso return the `Content-Type` of the attachment
  if one is stored in the database (or `application/octet-stream` otherwise)
  in the format `{:ok, data, content_type}`.
  """
  @spec attachment_get(
    db :: String.t, id :: String.t, name :: String.t, rev :: String.t
  ) :: {:ok, binary, String.t} | {:error, term}
  def attachment_get(db, id, doc_rev, name) do
    GenServer.call(CouchDBEx.Worker, {:attachment_get, db, id, doc_rev, name}, :infinity)
  end

  @doc """
  Delete an attachment from the document.

  This function returns new document revision, as well as it's id.
  """
  @spec attachment_delete(
    db :: String.t, id :: String.t, name :: String.t, rev :: String.t
  ) :: couchdb_res
  def attachment_delete(db, id, doc_rev, name) do
    GenServer.call(CouchDBEx.Worker, {:attachment_delete, db, id, doc_rev, name}, :infinity)
  end


  ## Indexes


  @doc """
  Create an index.

  If `index` is a list, it is considered a list of indexing fields, otherwise it is used
  as a full [index specification](http://docs.couchdb.org/en/2.1.1/api/database/find.html#api-db-find-index).
  Options are as specified there too.

  """
  @spec index_create(index :: map | [String.t], db :: String.t, opts :: keyword) :: couchdb_res
  def index_create(index, db, opts \\ []) do
    GenServer.call(CouchDBEx.Worker, {:index_create, index, db, opts})
  end

  @doc """
  Delete the index `index_name` from the specified design document `ddoc`.
  """
  @spec index_delete(db :: String.t, ddoc :: String.t, index_name :: String.t) :: :ok | {:error, term}
  def index_delete(db, ddoc, index_name) do
    GenServer.call(CouchDBEx.Worker, {:index_delete, db, ddoc, index_name})
  end

  @doc """
  Lists all indexes and their count.

  This function returns it's data in the following format:
  `{:ok, a list of index specifications, total number of indexes}`.
  Those specifications are described
  [here](http://docs.couchdb.org/en/2.1.1/api/database/find.html#get--db-_index)
  """
  @spec index_list(db :: String.t) :: {:ok, [map], integer} | {:error, term}
  def index_list(db), do: GenServer.call(CouchDBEx.Worker, {:index_list, db})


  ## Replication


  @doc """
  Replicate a database

  Options are as desribed [here](http://docs.couchdb.org/en/2.1.1/api/server/common.html#replicate),
  except that source and target are already provided
  """
  @spec replicate(src :: String.t, target :: String.t, opts :: keyword) :: couchdb_res
  def replicate(src, target, opts \\ []), do: GenServer.call(CouchDBEx.Worker, {:replicate, src, target, opts})


  ## Config


  @doc """
  Set the configuration option for the CouchDB server.

  Any option can be nil here, that just goes a level up. If `section` is nil, the key is also ignored.
  """
  @spec config_get(
    node_name :: String.t | nil,
    section :: String.t | nil,
    key :: String.t | nil
  ) :: couchdb_res
  def config_get(node_name \\ nil, section \\ nil, key \\ nil) do
    GenServer.call(CouchDBEx.Worker, {:config_get, node_name, section, key})
  end

  @doc """
  Set a configuration option for the CouchDB server.
  """
  @spec config_set(
    node_name :: String.t,
    section :: String.t,
    key :: String.t,
    value :: String.t
  ) :: couchdb_res
  def config_set(node_name, section, key, value) do
    GenServer.call(CouchDBEx.Worker, {:config_set, node_name, section, key, value})
  end


  ## Changes


  @doc """
  Subscribe to changes to the table.

  `watcher_name` is the process name the caller wants the watcher to be known as,
  the watcher may set this name on start (it will be passed as `:name` in the options
  list) so that other processes could communicate with it, otherwise it is used only as a `Supervisor` id.
  This facilitates module reuse, as one might want to use same modules on different databases.
  `modname` is the actual module that will be passed to the supervisor, which
  in turn will start it.

  ## The watching module

  The module passed to this function will periodically receive update messages from the database
  in the tuple with `:couchdb_change` as it's first element and the change as the second element.
  If the module crashes, it will be restarted by a supervisor. To stop the watcher and remove it,
  see `CouchDBEx.changes_unsub/1`

  ## Module example

      defmodule ChangesTest do
        use GenServer

        def start_link(opts) do
          GenServer.start_link(__MODULE__, nil, opts)
        end

        def init(_) do
          {:ok, nil}
        end

        def handle_info({:couchdb_change, msg}, _) do
          # Just logs the change to the stdout
          IO.inspect msg

          {:noreply, nil}
        end

      end


  ## Options

  Options are as described in
  [the official documentation](http://docs.couchdb.org/en/2.1.1/api/database/changes.html),
  except the following defaults:
  * `feed` is `continuous`, this is the only mode supported, trying to change it **WILL RAISE A RuntimeError**
  * `include_docs` is `true`
  * `since` is `now`
  * `heartbeat` is `25`, this is needed to keep the connection alive,
                trying to change it **WILL RAISE a RuntimeError**

  One can also pass arguments to the watcher by using `:pass_args` option.
  Do note that your arguments will override the default (e.h. `:name`)
  """
  def changes_sub(db, modname, watcher_name, opts \\ []) do
    GenServer.cast(CouchDBEx.Worker, {:changes_sub, db, modname, watcher_name, opts})
  end

  @doc """
  Unsubscribe the `modname` watcher from changes in the database.

  `modname` is the module's name as known to the supervisor, not the actual running module.
  """
  def changes_unsub(modname), do: GenServer.cast(CouchDBEx.Worker, {:changes_unsub, modname})


  ##  Design documents


  @doc """
  Insert or update a design document.

  Read more about design documents' fields
  [here](http://docs.couchdb.org/en/2.1.1/api/ddoc/common.html#db-design-design-doc)
  """
  @spec ddoc_insert(ddoc :: map, name :: String.t, db :: String.t) :: couchdb_res
  def ddoc_insert(ddoc, name, db), do: GenServer.call(CouchDBEx.Worker, {:ddoc_insert, ddoc, name, db})

  @doc """
  Get a design document by name.

  This function is an alias for `CouchDBEx.document_get/3` that
  automatically adds `_design/` to the name.
  """
  @spec ddoc_get(name :: String.t, db :: String.t, opts :: keyword) :: couchdb_res
  def ddoc_get(name, db, opts \\ []), do: GenServer.call(CouchDBEx.Worker, {:ddoc_get, name, db, opts})

  @doc """
  Delete a design document.

  This function is an alias for `CouchDBEx.document_delete_one/3` that automatically
  appends `_design/` to the name.
  """
  @spec ddoc_delete(name :: String.t, rev :: String.t, db :: String.t) :: couchdb_res
  def ddoc_delete(name, rev, db), do: GenServer.call(CouchDBEx.Worker, {:ddoc_delete, name, rev, db})


  ## Views

  @doc """
  Execute a view function from a design document.

  Read more about options [here](http://docs.couchdb.org/en/2.1.1/api/ddoc/views.html#get--db-_design-ddoc-_view-view)
  """
  @spec view_exec(ddoc :: String.t, view :: String.t, db :: String.t, opts :: keyword) :: couchdb_res
  def view_exec(ddoc, view, db, opts \\ []) do
    GenServer.call(CouchDBEx.Worker, {:view_exec, ddoc, view, db, opts}, :infinity)
  end

end
