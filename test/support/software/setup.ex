defmodule Helix.Test.Software.Setup do

  alias Ecto.Changeset
  alias Helix.Cache.Query.Cache, as: CacheQuery
  alias Helix.Hardware.Model.Component
  alias Helix.Server.Model.Server
  alias Helix.Software.Internal.File, as: FileInternal
  alias Helix.Software.Internal.StorageDrive, as: StorageDriveInternal
  alias Helix.Software.Model.File
  alias Helix.Software.Model.Storage
  alias Helix.Software.Model.PublicFTP
  alias Helix.Software.Model.StorageDrive
  alias Helix.Software.Repo, as: SoftwareRepo

  alias Helix.Test.Cache.Helper, as: CacheHelper
  alias Helix.Test.Server.Setup, as: ServerSetup
  alias Helix.Test.Software.Helper, as: SoftwareHelper

  @doc """
  Generates a bunch of files

  total: Set total of files to be generated. Defaults to 5
  file_opts: Opts of the files that will be created
  """
  def random_files(opts \\ []) do
    upper = Access.get(opts, :total, 5)

    1..upper
    |> Enum.map(fn _ -> file(opts[:file_opts])  end)
  end

  def random_files!(opts \\ []) do
    files = random_files(opts)

    files
    |> Enum.map(&(elem(&1, 0)))
  end

  @doc """
  See doc on `fake_file/1`
  """
  def file(opts \\ []) do
    {_, related = %{params: params, modules: modules}} = fake_file(opts)
    {:ok, inserted} = FileInternal.create(params, modules)

    file =
      if params.crypto do
        {:ok, f} = FileInternal.encrypt(inserted, params.crypto)
        f
      else
        inserted
      end

    # Sync here because internally we used a CacheQuery. If we don't, any tests
    # calling `SoftwareSetup.[random_]file` would have to sync, and in some
    # cases it wouldn't be obvious why they are required to sync
    CacheHelper.sync_test()

    {file, related}
  end

  def file!(opts \\ []) do
    {file, _} = file(opts)
    file
  end

  @doc """
  - name: Set file name
  - size: Set file size
  - type: Set file type. Software.type
  - path: Set file path
  - modules: Set file module. If set, `type` must also be set.
  - server_id: Server that file belongs to. Will use the first storage it finds.
  - storage_id: Specify storage ID to use. If set, ignores server params, and no
    server is generated. Enhance as you see fit.
  - fake_server: Whether to use a fake server. Gives the option to create a
    storage without a server. Defaults to false.
  - crypto_version: Mark that file as encrypted. Defaults to nil (unencrypted).

  Related: File.creation_params, [File.module_params], Storage.id, Server.id
  """
  def fake_file(opts \\ []) do
    if not is_nil(opts[:modules]) and is_nil(opts[:type]) do
      raise "You can't specify a module and ask for a random file type."
    end

    size = Access.get(opts, :size, Enum.random(1..1_048_576))
    name = Access.get(opts, :name, SoftwareHelper.random_file_name())
    path = Access.get(opts, :path, SoftwareHelper.random_file_path())
    type = Access.get(opts, :type, SoftwareHelper.random_file_type())
    crypto = Access.get(opts, :crypto_version, nil)
    modules = Access.get(opts, :modules, SoftwareHelper.get_modules(type))

    {storage_id, server_id} = file_get_storage_and_server(opts)

    params = %{
      file_size: size,
      name: name,
      software_type: type,
      path: path,
      storage_id: storage_id,
      crypto: crypto
    }

    related = %{
      params: params,
      storage_id: storage_id,
      server_id: server_id,
      modules: modules
    }

    file = File.create_changeset(params, modules)

    {file, related}
  end

  # This is actually a workaround for credo.
  defp file_get_storage_and_server(opts) do
    cond do
      opts[:server_id] ->
        {:ok, storages} =
          CacheQuery.from_server_get_storages(opts[:server_id])

        {List.first(storages), opts[:server_id]}

      opts[:storage_id] ->
        {opts[:storage_id], nil}

      # Only create storage, not the server
      opts[:fake_server] ->
        {storage, _} = storage()

        {storage.storage_id, nil}

      # Default: Generate a real server
      true ->
        server = ServerSetup.server!()
        {:ok, storages} =
          CacheQuery.from_server_get_storages(server.server_id)

        {List.first(storages), server}
    end
  end

  @doc """
  See docs on `fake_storage/1`
  """
  def storage(opts \\ []) do
    {storage, related} = fake_storage(opts)
    {:ok, inserted} = SoftwareRepo.insert(storage)

    :ok = StorageDriveInternal.link_drive(inserted, related.drive_id)

    storage_preloaded =
      storage
      |> SoftwareRepo.preload(:drives)

    {storage_preloaded, related}
  end

  @doc """
  No opts for you
  Related: StorageDrive.t, drive :: Component.id
  """
  def fake_storage(_opts \\ []) do
    drive_id = Component.ID.generate()

    storage =
      %Storage{
        storage_id: Storage.ID.generate()
      }

    storage_drive =
      %StorageDrive{
        storage_id: storage.storage_id,
        drive_id: drive_id
      }

    related = %{
      storage_drive: storage_drive,
      drive_id: drive_id
    }

    {storage, related}
  end

  @doc """
  See docs on `fake_pftp/1`
  """
  def pftp(opts \\ []) do
    {pftp, related} = fake_pftp(opts)

    {:ok, inserted} = SoftwareRepo.insert(pftp)

    {inserted, related}
  end

  @doc """
  Opts:
  - server_id: Specify the server id. Defaults to generating a fake server id.
  - active: Whether the generated pftp should be active. Defaults to true.
  - real_server: Whether to generate a real server (desktop). Defaults to false.

  Related: Server.t if `real_server`
  """
  def fake_pftp(opts \\ []) do
    if opts[:server_id] != nil and opts[:real_server] != nil do
      raise "Cant use both `real_server` and `server_id` opts"
    end

    is_active = Keyword.get(opts, :active, true)

    {server, server_id} =
      cond do
        opts[:real_server] ->
          {server, _} = ServerSetup.server()
          {server, server.server_id}
        opts[:server_id] ->
          {nil, opts[:server_id]}
        true ->
          {nil, Server.ID.generate()}
      end

    pftp =
      server_id
      |> PublicFTP.create_server()
      |> Changeset.force_change(:is_active, is_active)
      |> Changeset.apply_changes()

    related =
      if server do
        %{server: server}
      else
        %{}
      end

    {pftp, related}
  end

  @doc """
  See doc on `fake_pftp_file/1`
  """
  def pftp_file(opts \\ []) do
    {pftp_file, related} = fake_pftp_file(opts)

    {:ok, inserted} = SoftwareRepo.insert(pftp_file)

    {inserted, related}
  end

  @doc """
  - file_id: Specify file id. Generates a real file if not specified.
  - real_file: Whether to generate a real file. Defaults to true. Overwrites the
    `file_id` option when set.
  - server_id: Which pftp server to link to. Generates a real pftp by default

  Related:
    File.t if `real_file` is true (default), \
    PublicFTP.t when `server_id` isnt specified, \
    Server.id,
    File.id
  """
  def fake_pftp_file(opts \\ []) do
    {file, file_related, file_id} =
      cond do
        opts[:real_file] == false ->
          {nil, nil, File.ID.generate()}

        opts[:file_id] ->
          {nil, nil, opts[:file_id]}

        true ->
          {file, related} = file()
          {file, related, file.file_id}
      end

    server_id =
      if file do
        Keyword.get(opts, :server_id, file_related.server_id)
      else
        Keyword.get(opts, :server_id, Server.ID.generate())
      end

    pftp =
      if opts[:server_id] do
        nil
      else
        pftp(server_id: server_id)
      end

    pftp_file =
      server_id
      |> PublicFTP.File.add_file(file_id)
      |> Changeset.apply_changes()

    related = %{
      pftp: pftp,
      server_id: server_id,
      file: file,
      file_id: file_id
    }

    {pftp_file, related}
  end

  @doc """
  - bruteforce: set bruteforce module version. Defaults to random.
  - overflow: set overflow module version. Defaults to random.
  Remaining opts are passed to `file/1`
  """
  def cracker(opts \\ []) do
    bruteforce = Access.get(opts, :bruteforce, SoftwareHelper.random_version())
    overflow = Access.get(opts, :overflow, SoftwareHelper.random_version())

    version_map = %{
      bruteforce: bruteforce,
      overflow: overflow
    }

    modules = SoftwareHelper.generate_module(:cracker, version_map)

    file(opts ++ [type: :cracker, modules: modules])
  end

  @doc """
  Generates a non-executable file
  """
  def non_executable_file do
    file(type: :crypto_key)
  end
end
