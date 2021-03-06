defmodule Helix.Event.Publishable.Flow do

  import HELL.Macros

  alias Phoenix.Socket
  alias HELL.HETypes
  alias Helix.Event
  alias Helix.Event.Publishable

  @type event_id :: HETypes.uuid

  @doc """
  Top-level macro for an event that wants to implement the Publishable protocol.
  """
  defmacro publish(do: block) do
    quote do

      defimpl Helix.Event.Publishable do
        @moduledoc false

        @event nil

        unquote(block)

        @event || raise "You must set an event name with @event"

        @doc """
        Returns the event name as a string
        """
        def get_event_name(_event) do
          to_string(@event)
        end
      end

    end
  end

  @spec generate_event(struct, Socket.t) ::
    {:ok, %{data: term, event: String.t, meta: Event.Meta.rendered}}
    | :noreply
  @doc """
  Attempts to generate the payload for that event. If the implementation of the
  Publishable protocol returns a valid payload (i.e. it wants to publish to that
  specific user), then we'll set up the event metadata and return it ready to
  be sent to the player.
  """
  def generate_event(event, socket) do
    case Publishable.generate_payload(event, socket) do
      {:ok, data} ->
        payload =
          %{
            data: data,
            event: Publishable.get_event_name(event),
            meta: Event.Meta.render(event)
          }

        {:ok, payload}

      noreply ->
        noreply
    end
  end

  @spec add_event_identifier(struct) ::
    struct
  @doc """
  Adds the event unique identifier.

  Keep in mind that this unique identifier is for the *event*, i.e. the fact
  that something happened. If this event gets broadcasted to multiple players,
  each one of them will share the same event identifier.
  """
  def add_event_identifier(event),
    do: Event.set_event_id(event, generate_event_uuid())

  @spec generate_event_uuid ::
    event_id
  docp """
  Returns a valid UUIDv4 used as event identifier.
  """
  defp generate_event_uuid,
    do: Ecto.UUID.generate()
end
