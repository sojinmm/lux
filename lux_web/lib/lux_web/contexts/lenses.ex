defmodule LuxWeb.Contexts.Lenses do
  @moduledoc """
  The Lenses context.
  """

  import Ecto.Query, warn: false
  alias LuxWeb.Repo
  alias LuxWeb.Schemas.Lens

  @doc """
  Returns the list of lenses with pagination and filtering.

  ## Examples

      iex> list_lenses(%{})
      {:ok, {[%Lens{}, ...], %Flop.Meta{}}}

  """
  def list_lenses(params) do
    Flop.validate_and_run(Lens, params, for: Lens)
  end

  @doc """
  Gets a single lens.

  Raises `Ecto.NoResultsError` if the Lens does not exist.

  ## Examples

      iex> get_lens!(123)
      %Lens{}

      iex> get_lens!(456)
      ** (Ecto.NoResultsError)

  """
  def get_lens!(id), do: Repo.get!(Lens, id)

  @doc """
  Gets a single lens.

  Returns `nil` if the Lens does not exist.

  ## Examples

      iex> get_lens(123)
      %Lens{}

      iex> get_lens(456)
      nil

  """
  def get_lens(id), do: Repo.get(Lens, id)

  @doc """
  Creates a lens.

  ## Examples

      iex> create_lens(%{field: value})
      {:ok, %Lens{}}

      iex> create_lens(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_lens(attrs \\ %{}) do
    %Lens{}
    |> Lens.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a lens.

  ## Examples

      iex> update_lens(lens, %{field: new_value})
      {:ok, %Lens{}}

      iex> update_lens(lens, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_lens(%Lens{} = lens, attrs) do
    lens
    |> Lens.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a lens.

  ## Examples

      iex> delete_lens(lens)
      {:ok, %Lens{}}

      iex> delete_lens(lens)
      {:error, %Ecto.Changeset{}}

  """
  def delete_lens(%Lens{} = lens) do
    Repo.delete(lens)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking lens changes.

  ## Examples

      iex> change_lens(lens)
      %Ecto.Changeset{data: %Lens{}}

  """
  def change_lens(%Lens{} = lens, attrs \\ %{}) do
    Lens.changeset(lens, attrs)
  end
end
