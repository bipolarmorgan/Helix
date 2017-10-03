defmodule Helix.Test.Event.Setup.Software do

  alias Helix.Entity.Model.Entity
  alias Helix.Network.Model.Connection
  alias Helix.Process.Model.Process
  alias Helix.Server.Model.Server

  alias Helix.Software.Event.File.Downloaded, as: FileDownloadedEvent
  alias Helix.Software.Event.File.DownloadFailed, as: FileDownloadFailedEvent
  alias Helix.Software.Event.File.Uploaded, as: FileUploadedEvent
  alias Helix.Software.Event.File.UploadFailed, as: FileUploadFailedEvent
  # alias Helix.Software.Event.File.Transfer.Processed,
  #   as: FileTransferProcessedEvent

  alias Helix.Software.Model.Software.Cracker.Bruteforce.ConclusionEvent,
    as: BruteforceConclusionEvent
  alias Helix.Software.Model.Software.Cracker.Overflow.ConclusionEvent,
    as: OverflowConclusionEvent

  alias HELL.TestHelper.Random
  alias Helix.Test.Network.Helper, as: NetworkHelper
  alias Helix.Test.Process.TOPHelper
  alias Helix.Test.Software.Setup.Flow, as: SoftwareFlowSetup

  @internet NetworkHelper.internet_id()

  @doc """
  Accepts:
    Process.t
    | Connection.t, Server.id
  """
  def overflow_conclusion(process = %Process{}) do
    %OverflowConclusionEvent{
      gateway_id: process.gateway_id,
      target_process_id: process.process_id,
      target_connection_id: nil
    }
  end
  def overflow_conclusion(connection = %Connection{}, gateway_id) do
    %OverflowConclusionEvent{
      gateway_id: gateway_id,
      target_process_id: nil,
      target_connection_id: connection.connection_id
    }
  end

  def bruteforce_conclusion(process = %Process{}) do
    %BruteforceConclusionEvent{
      source_entity_id: process.source_entity_id,
      network_id: process.network_id,
      target_server_id: process.target_server_id,
      target_server_ip: process.process_data.target_server_ip,
    }
  end
  def bruteforce_conclusion do
    %BruteforceConclusionEvent{
      source_entity_id: Entity.ID.generate(),
      network_id: @internet,
      target_server_id: Server.ID.generate(),
      target_server_ip: Random.ipv4()
    }
  end

  def file_downloaded do
    {event, _} = setup_env(:download, :completed)
    event
  end

  def file_download_failed(reason) do
    {event, _} = setup_env(:download, {:failed, reason})
    event
  end

  def file_uploaded do
    {event, _} = setup_env(:upload, :completed)
    event
  end

  def file_upload_failed(reason) do
    {event, _} = setup_env(:upload, {:failed, reason})
    event
  end

  @spec setup_env(:download | :upload, :completed | :failed) ::
    {event :: term, related :: term}
  defp setup_env(type, :completed) do
    # We'll generate the event data based on a real process.
    # That's not necessary, we could generate everything directly here, but by
    # using the process implementation, we are centralizing the implementation
    # in a singe place, so future changes must be made only on SoftwareFlowSetup
    {process, _} = SoftwareFlowSetup.file_transfer(type)

    {_, [event]} = TOPHelper.soft_complete(process)

    # Stop TOP, since we've only used it to infer the event data.
    TOPHelper.top_stop(process.gateway_id)

    new_file =
      copy_file(process.file_id, process.process_data.destination_storage_id)

    event = generate_event(event, type, {:completed, new_file})
    {event, %{}}
  end

  defp setup_env(type, {:failed, reason}) do
    {process, _} = SoftwareFlowSetup.file_transfer(type)
    {_, event} = TOPHelper.soft_complete(process)
    TOPHelper.top_stop(process.gateway_id)

    event = generate_event(event, type, {:failed, reason})
    {event, %{}}
  end

  defp generate_event(event, :download, {:completed, file}) do
    %FileDownloadedEvent{
      entity_id: event.entity_id,
      to_server_id: event.to_server_id,
      from_server_id: event.from_server_id,
      network_id: event.network_id,
      connection_type: event.connection_type,
      file: file
    }
  end
  defp generate_event(event, :download, {:failed, reason}) do
    %FileDownloadFailedEvent{
      entity_id: event.entity_id,
      to_server_id: event.to_server_id,
      from_server_id: event.from_server_id,
      network_id: event.network_id,
      connection_type: event.connection_type,
      reason: reason
    }
  end
  defp generate_event(event, :upload, {:completed, file}) do
    %FileUploadedEvent{
      entity_id: event.entity_id,
      to_server_id: event.to_server_id,
      from_server_id: event.from_server_id,
      network_id: event.network_id,
      file: file
    }
  end
  defp generate_event(event, :upload, {:failed, reason}) do
    %FileUploadFailedEvent{
      entity_id: event.entity_id,
      to_server_id: event.to_server_id,
      from_server_id: event.from_server_id,
      network_id: event.network_id,
      reason: reason
    }
  end

  alias Helix.Software.Internal.File, as: FileInternal
  alias Helix.Software.Internal.Storage, as: StorageInternal
  defp copy_file(file_id, storage_id, path \\ nil) do
    file = FileInternal.fetch(file_id)

    storage = StorageInternal.fetch(storage_id)

    path =
      if path do
        path
      else
        file.path
      end

    {:ok, new_file} = FileInternal.copy(file, storage, path)
    new_file
  end
end
