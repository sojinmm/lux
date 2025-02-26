defmodule LuxWeb.Contexts.Beams do
  @moduledoc """
  The Beams context.
  """

  import Ecto.Query, warn: false
  alias LuxWeb.Repo
  alias LuxWeb.Schemas.Beam

  @doc """
  Returns the list of beams with pagination and filtering.

  ## Examples

      iex> list_beams(%{})
      {:ok, {[%Beam{}, ...], %Flop.Meta{}}}

  """
  def list_beams(params) do
    Flop.validate_and_run(Beam, params, for: Beam)
  end

  @doc """
  Gets a single beam.

  Raises `Ecto.NoResultsError` if the Beam does not exist.

  ## Examples

      iex> get_beam!(123)
      %Beam{}

      iex> get_beam!(456)
      ** (Ecto.NoResultsError)

  """
  def get_beam!(id), do: Repo.get!(Beam, id)

  @doc """
  Gets a single beam.

  Returns `nil` if the Beam does not exist.

  ## Examples

      iex> get_beam(123)
      %Beam{}

      iex> get_beam(456)
      nil

  """
  def get_beam(id), do: Repo.get(Beam, id)

  @doc """
  Creates a beam.

  ## Examples

      iex> create_beam(%{field: value})
      {:ok, %Beam{}}

      iex> create_beam(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_beam(attrs \\ %{}) do
    %Beam{}
    |> Beam.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a beam.

  ## Examples

      iex> update_beam(beam, %{field: new_value})
      {:ok, %Beam{}}

      iex> update_beam(beam, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_beam(%Beam{} = beam, attrs) do
    beam
    |> Beam.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a beam.

  ## Examples

      iex> delete_beam(beam)
      {:ok, %Beam{}}

      iex> delete_beam(beam)
      {:error, %Ecto.Changeset{}}

  """
  def delete_beam(%Beam{} = beam) do
    Repo.delete(beam)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking beam changes.

  ## Examples

      iex> change_beam(beam)
      %Ecto.Changeset{data: %Beam{}}

  """
  def change_beam(%Beam{} = beam, attrs \\ %{}) do
    Beam.changeset(beam, attrs)
  end
end
