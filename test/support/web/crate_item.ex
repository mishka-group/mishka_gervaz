defmodule MishkaGervaz.Test.Web.CrateItem do
  @moduledoc """
  The resource of `MishkaGervaz.Test.Web.CratePageLive`'s form: a crate a person files.

    * `:title` — a required text field;
    * `:manifest` — an upload that names no `accept`, so it takes a file of any type; the create
      action keeps the handed-over file's client name, path and contents in `:manifest_name`,
      `:manifest_path` and `:manifest_body`;
    * `:weight` and `:weight_unit` — a virtual number and a virtual select of `g` or `kg`, both
      derived on edit from the one stored `:weight_grams`, which the actions work out from them;
    * `:tag_ids` — a `:search_multi` relation over `MishkaGervaz.Test.Web.CrateTag`, whose `load`
      offers only active tags.
  """

  use Ash.Resource,
    domain: MishkaGervaz.Test.Domain,
    extensions: [MishkaGervaz.Resource],
    data_layer: Ash.DataLayer.Ets

  require Ash.Query

  mishka_gervaz do
    form do
      identity do
        name :crate_items
        route "/crates"
      end

      source do
        actions do
          create {:create, :create}
          update {:update, :update}
          read {:read, :read}
        end
      end

      fields do
        field :title, :text, required: true
        field :manifest, :upload

        field :weight, :number do
          virtual true
          derive_value &MishkaGervaz.Test.Web.CrateItem.weight/1
        end

        field :weight_unit, :select do
          virtual true
          options [{"g", "g"}, {"kg", "kg"}]
          derive_value &MishkaGervaz.Test.Web.CrateItem.weight_unit/1
        end

        field :tag_ids, :relation do
          resource MishkaGervaz.Test.Web.CrateTag
          display_field :name
          mode :search_multi
          load fn query, _state -> Ash.Query.filter(query, active == true) end
        end
      end

      uploads do
        upload :manifest do
          max_entries 1
        end
      end
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:title, :weight_grams, :tag_ids]
      argument :weight, :integer
      argument :weight_unit, :string
      argument :manifest, {:array, :map}
      change &MishkaGervaz.Test.Web.CrateItem.put_weight_grams/2
      change &MishkaGervaz.Test.Web.CrateItem.put_manifest/2
    end

    update :update do
      primary? true
      accept [:title, :tag_ids]
      require_atomic? false
      argument :weight, :integer
      argument :weight_unit, :string
      change &MishkaGervaz.Test.Web.CrateItem.put_weight_grams/2
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    attribute :weight_grams, :integer, public?: true
    attribute :tag_ids, {:array, :uuid}, default: [], public?: true
    attribute :manifest_name, :string, public?: true
    attribute :manifest_path, :string, public?: true
    attribute :manifest_body, :string, public?: true
  end

  @doc "The weight the form shows: in kg when the stored grams are whole kilograms."
  def weight(%{weight_grams: nil}), do: nil
  def weight(%{weight_grams: grams}) when rem(grams, 1000) == 0, do: div(grams, 1000)
  def weight(%{weight_grams: grams}), do: grams

  @doc "The unit `weight/1` is in."
  def weight_unit(%{weight_grams: nil}), do: nil
  def weight_unit(%{weight_grams: grams}) when rem(grams, 1000) == 0, do: "kg"
  def weight_unit(_crate), do: "g"

  @doc "Stores the weight and unit the form sends as grams."
  def put_weight_grams(changeset, _context) do
    case {Ash.Changeset.get_argument(changeset, :weight),
          Ash.Changeset.get_argument(changeset, :weight_unit)} do
      {nil, _unit} -> changeset
      {weight, "kg"} -> Ash.Changeset.change_attribute(changeset, :weight_grams, weight * 1000)
      {weight, _grams} -> Ash.Changeset.change_attribute(changeset, :weight_grams, weight)
    end
  end

  @doc """
  Keeps the client name, path and contents of the manifest file the form hands over, and refuses a
  manifest whose file is gone.
  """
  def put_manifest(changeset, _context) do
    with [%{path: path, client_name: name} | _] <-
           Ash.Changeset.get_argument(changeset, :manifest),
         {:ok, body} <- File.read(path) do
      Ash.Changeset.change_attributes(changeset,
        manifest_name: name,
        manifest_path: path,
        manifest_body: body
      )
    else
      {:error, _reason} ->
        Ash.Changeset.add_error(changeset, field: :manifest, message: "could not be read")

      _none ->
        changeset
    end
  end
end
