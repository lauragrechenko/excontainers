defmodule Docker.Network do
  @moduledoc """
  Specification for a _container_.
  """

  @enforce_keys [:name]

  defstruct [
    :name
  ]

  @doc """
  Creates a network with the given name

  - `name` The network's name.
  """
  def new(name, _opts \\ []) do
    %__MODULE__{
      name: name
    }
  end
end
