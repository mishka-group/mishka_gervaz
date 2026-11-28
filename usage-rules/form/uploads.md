# Form → `uploads`

File uploads. Each `upload :name` pairs with a `field :name, :upload`.

```elixir
uploads do
  upload :media_files do
    accept ~w(.jpg .jpeg .png .webp .pdf)     # or "image/*,.pdf"
    max_entries 1
    max_file_size 50_000_000                   # bytes; default 8_000_000
    show_preview true
    auto_upload false
    style :dropzone                            # :dropzone | :file_input | :custom
    dropzone_text "Drop image here"
    field :cover                               # the form field this upload belongs to
    chunk_size 64_000
    chunk_timeout 10_000
    external MyApp.S3Uploader                  # module, or fn entry, socket ->
    writer MyApp.UploadWriter

    existing fn record ->
      if record.relative_path do
        [%{filename: record.name, id: record.id, url: record.relative_path,
           type: record.type, size: record.size, format: record.format}]
      else
        []
      end
    end

    ui do
      label fn -> dgettext("mishka_gervaz", "Files") end
      icon "hero-photo"
      class "border-dashed"
      preview_class "w-32 h-32"
    end
  end
end
```

| Option | Type | Default | Note |
|---|---|---|---|
| `name` | atom | — | **required**; matches the `allow_upload` key |
| `field` | atom | — | the form field this upload belongs to |
| `accept` | string \| `[string]` | — | `"image/*,.pdf"` or `~w(.jpg .png)` |
| `max_entries` | pos int | `1` | |
| `max_file_size` | pos int | `8_000_000` | bytes |
| `show_preview` | bool | `true` | ⚠ compiled but not read by the built-in template |
| `dropzone_text` | string \| `fn -> string` | — | ⚠ compiled but not read — use `ui do label … end` |
| `auto_upload` | bool | `false` | upload on selection |
| `style` | `:dropzone` \| `:file_input` \| `:custom` | `:dropzone` | `:custom` is a bare `live_file_input` |
| `chunk_size` / `chunk_timeout` | pos int | — | chunked transport |
| `external` | module \| `fn entry, socket ->` | — | direct-to-S3 and friends |
| `writer` | module | — | custom `UploadWriter` |
| `existing` | atom \| `fn record -> list` | — | already-uploaded files in edit mode |

`ui`: `label` · `icon` · `class` · `preview_class` · `extra`.

## Pair the upload with a field

```elixir
fields do
  field :media_files, :upload do
    ui do label fn -> dgettext("mishka_gervaz", "Files") end end
  end
end
```

A field of type `:upload` is forced `virtual: true` automatically — it is not a resource
attribute.

## Names are namespaced per component

At `allow_upload` time the name becomes `<upload_name>` scoped by the component id, so **several
forms on one page never collide**. Do not hand-write the namespaced name; use the plain one in the
DSL and let the library scope it.

## What the action gets

On save, each file reaches the action under its field as
`%{path:, client_name:, client_type:, client_size:}`. `path` is a copy at a random name in the
temp folder, removed once the save returns, so the action copies or reads it before it returns.
The client's name never goes into a path: `client_name` is only data, the part after the last `/`
or `\` with control characters taken out (`"../../etc/passwd"` arrives as `"passwd"`). Build the
stored path from your own id, not from `client_name`.

## Rules the compiler enforces

- `field` names a field declared in this form.
- `accept` is a valid HTML accept string or list of MIME types / extensions.
- `external` (when a module) and `writer` are loadable modules.

## TODO
- [ ] A `field :name, :upload` exists for every `upload :name`
- [ ] `accept` and `max_file_size` match the Ash action's own validation
- [ ] `existing` supplied, or edit mode shows nothing already uploaded
- [ ] `external` / `writer` modules compile
- [ ] `max_entries` matches what the action stores (one path vs a list)
- [ ] Temp files are cleaned up by the action, not left to the form

## DSL reference

Generated from the schema, always current:

- Resource — [`mishka_gervaz.form.uploads`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-form-uploads) · [`mishka_gervaz.form.uploads.upload`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-form-uploads-upload) · [`mishka_gervaz.form.uploads.upload.ui`](https://hexdocs.pm/mishka_gervaz/dsl-mishkagervaz-resource.html#mishka_gervaz-form-uploads-upload-ui)

**Schema:** `MishkaGervaz.Form.Dsl.Uploads`, `Form.Entities.Upload`, `.Upload.Ui` ·
**Verifier:** `Form.Verifiers.ValidateUploads` · **Runtime:** `Form.Web.UploadHelpers`
