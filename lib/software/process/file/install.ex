import Helix.Process

process Helix.Software.Process.File.Install do
  @moduledoc """
  `InstallFileProcess` is a generic process for installing files. The
  installation is specialized by the requested backend (e.g. installing viruses
  uses the `virus` backend). The backend defines what's supposed to happen once
  the process finishes, as well as how much resources it should take, etc.
  """

  alias Helix.Software.Model.File
  alias __MODULE__, as: FileInstallProcess

  alias Helix.Software.Event.File.Install.Processed,
    as: FileInstallProcessedEvent

  process_struct [:backend]

  @type process_type :: :install_virus
  @type backend :: :virus

  @type t ::
    %__MODULE__{
      backend: backend
    }

  @type resources ::
    %{
      objective: objective,
      l_dynamic: [:cpu],
      r_dynamic: [],
      static: map
    }

  @type creation_params :: %{backend: backend}

  @type objective :: %{cpu: resource_usage}

  @type resources_params ::
    %{
      file: File.t,
      backend: backend
    }

  @spec new(creation_params) ::
    t
  def new(%{backend: backend}) do
    %__MODULE__{
      backend: backend
    }
  end

  @spec resources(resources_params) ::
    resources
  def resources(params = %{file: %File{}, backend: _}),
    do: get_resources(params)

  @spec get_backend(File.t) ::
    backend
  @doc """
  Based on the file to be installed, identify its backend.

  Currently only returns `:virus` as it's the only backend...
  """
  def get_backend(%File{}),
    do: :virus

  @spec get_process_type(backend) ::
    process_type
  def get_process_type(:virus),
    do: :install_virus

  processable do

    on_completion(process, data) do
      event = FileInstallProcessedEvent.new(process, data)

      {:delete, [event]}
    end

    def after_read_hook(data) do
      %FileInstallProcess{
        backend: String.to_existing_atom(data.backend)
      }
    end
  end

  resourceable do

    alias Helix.Software.Factor.File, as: FileFactor

    @type params :: FileInstallProcess.resources_params

    @type factors :: term

    get_factors(%{file: file, backend: _}) do

      # Retrieves information about the file to be installed
      factor FileFactor, %{file: file},
        only: [:version, :size]
    end

    # TODO: Use time as a resource instead. #364
    cpu(_) do
      300
    end

    dynamic do
      [:cpu]
    end
  end

  executable do

    @type params :: FileInstallProcess.creation_params

    @type meta ::
      %{
        file: File.t,
        type: process_type
      }

    @typep process_type :: FileInstallProcess.process_type

    resources(_gateway, _target, %{backend: backend}, %{file: file}) do
      %{
        file: file,
        backend: backend
      }
    end

    source_connection(_gateway, _target, _params, %{ssh: ssh}) do
      ssh.connection_id
    end

    target_file(_gateway, _target, _params, %{file: file}) do
      file.file_id
    end
  end

  process_viewable do

    @type data :: %{}

    render_empty_data()
  end
end
