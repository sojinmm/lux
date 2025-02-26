defmodule LuxWeb.Contexts.Prisms do
  @moduledoc """
  The Prisms context.
  """

  import Ecto.Query, warn: false
  alias LuxWeb.Repo
  alias LuxWeb.Schemas.Prism

  @doc """
  Returns the list of prisms with pagination and filtering.

  ## Examples

      iex> list_prisms(%{})
      {:ok, {[%Prism{}, ...], %Flop.Meta{}}}

  """
  def list_prisms(params) do
    Flop.validate_and_run(Prism, params, for: Prism)
  end

  @doc """
  Gets a single prism.

  Raises `Ecto.NoResultsError` if the Prism does not exist.

  ## Examples

      iex> get_prism!(123)
      %Prism{}

      iex> get_prism!(456)
      ** (Ecto.NoResultsError)

  """
  def get_prism!(id), do: Repo.get!(Prism, id)

  @doc """
  Gets a single prism.

  Returns `nil` if the Prism does not exist.

  ## Examples

      iex> get_prism(123)
      %Prism{}

      iex> get_prism(456)
      nil

  """
  def get_prism(id), do: Repo.get(Prism, id)

  @doc """
  Creates a prism.

  ## Examples

      iex> create_prism(%{field: value})
      {:ok, %Prism{}}

      iex> create_prism(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_prism(attrs \\ %{}) do
    %Prism{}
    |> Prism.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a prism.

  ## Examples

      iex> update_prism(prism, %{field: new_value})
      {:ok, %Prism{}}

      iex> update_prism(prism, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_prism(%Prism{} = prism, attrs) do
    prism
    |> Prism.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a prism.

  ## Examples

      iex> delete_prism(prism)
      {:ok, %Prism{}}

      iex> delete_prism(prism)
      {:error, %Ecto.Changeset{}}

  """
  def delete_prism(%Prism{} = prism) do
    Repo.delete(prism)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking prism changes.

  ## Examples

      iex> change_prism(prism)
      %Ecto.Changeset{data: %Prism{}}

  """
  def change_prism(%Prism{} = prism, attrs \\ %{}) do
    Prism.changeset(prism, attrs)
  end
end
