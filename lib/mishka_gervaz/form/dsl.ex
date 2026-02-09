defmodule MishkaGervaz.Form.Dsl do
  @moduledoc """
  Form DSL definitions for MishkaGervaz.

  This module assembles all the form-related DSL sections into a single `form` section.
  Each section is defined in its own module under `MishkaGervaz.Form.Dsl.*`.

  ## Sections

  - `MishkaGervaz.Form.Dsl.Identity` - Naming and routing
  - `MishkaGervaz.Form.Dsl.Source` - Data fetching, action mapping, preloading
  - `MishkaGervaz.Form.Dsl.Fields` - Define form fields
  - `MishkaGervaz.Form.Dsl.Groups` - Define field groups
  - `MishkaGervaz.Form.Dsl.Layout` - Form layout configuration (including step definitions)
  - `MishkaGervaz.Form.Dsl.Uploads` - File upload configuration
  - `MishkaGervaz.Form.Dsl.Presentation` - UI adapter and theming
  - `MishkaGervaz.Form.Dsl.Hooks` - Lifecycle callbacks

  ## Entities

  - `MishkaGervaz.Form.Entities.Submit` - Submit/cancel button configuration
  - `MishkaGervaz.Form.Entities.Step` - Wizard/tab step configuration

  ## Form Modes

  | Mode | Steps required? | Behavior |
  |------|----------------|----------|
  | `:standard` | No (forbidden) | Normal form, all fields visible |
  | `:wizard` | Yes | Forced step-by-step, only current step visible, sequential |
  | `:tabs` | Yes | All steps visible as tabs/accordions, free or sequential |

  ## Structure

  ### Standard form (no steps)

  ```
  mishka_gervaz do
    form do
      identity do
        name :my_form
        route "/admin/my-resource"
      end

      source do
        actor_key :current_user
        master_check fn user -> user.role == :admin end

        actions do
          create {:master_create, :create}
          update {:master_update, :update}
          read {:master_get, :read}
        end

        preload do
          always [:category]
          master [:author]
          tenant []
        end
      end

      fields do
        field :name, :text do
          required true
          ui do
            label "Name"
          end
        end
      end

      groups do
        group :basic do
          fields [:name]
        end
      end

      layout do
        columns 2
        mode :standard
      end

      uploads do
        upload :avatar do
          accept "image/*"
          max_entries 1
        end
      end

      presentation do
        ui_adapter MyApp.UIAdapter

        theme do
          form_class "max-w-2xl"
        end
      end

      hooks do
        before_save fn params, state -> params end
        after_save fn result, state -> state end
      end

      submit do
        create_label "Create"
        update_label "Save"
      end
    end
  end
  ```

  ### Wizard form (multi-step)

  ```
  mishka_gervaz do
    form do
      identity do
        name :my_wizard_form
        route "/admin/my-resource"
      end

      fields do
        field :name, :text, required: true
        field :description, :textarea
        field :category, :select
      end

      groups do
        group :general, fields: [:name, :description]
        group :metadata, fields: [:category]
      end

      layout do
        mode :wizard
        columns 2
        navigation :sequential
        persistence :ets

        step :basic_info do
          groups [:general, :metadata]
          action :validate_basic
          on_enter fn state -> state end
          before_leave fn state -> state end

          ui do
            label "Basic Information"
            icon "hero-information-circle"
            description "Enter the basic details."
          end
        end

        step :review do
          groups [:general]
          summary true

          ui do
            label "Review & Submit"
            icon "hero-check-circle"
          end
        end
      end
    end
  end
  ```
  """

  alias MishkaGervaz.Form.Dsl.{
    Identity,
    Source,
    Fields,
    Groups,
    Layout,
    Uploads,
    Presentation,
    Hooks,
    Submit
  }

  @doc """
  Returns the `form` section definition.

  This section contains all form configuration subsections.
  """
  def section do
    %Spark.Dsl.Section{
      name: :form,
      describe: "Form configuration for admin interfaces.",
      sections: [
        Identity.section(),
        Source.section(),
        Fields.section(),
        Groups.section(),
        Layout.section(),
        Uploads.section(),
        Presentation.section(),
        Hooks.section()
      ],
      entities: [
        Submit.entity()
      ]
    }
  end
end
