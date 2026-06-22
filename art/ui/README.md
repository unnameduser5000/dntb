# UI art resource contract

Place future interface art here so scenes remain separate from artwork:

- `buttons/`: normal, hover, pressed, disabled button textures.
- `frames/`: panel and modal nine-patch textures.
- `icons/`: menu, settings, close, and gameplay icons.
- `backgrounds/`: menu backdrops and decorative layers.

The shared `res://scenes/ui/theme/UiTheme.tres` is the single integration point
for common button and panel visuals. Replace its `StyleBoxFlat` resources with
`StyleBoxTexture` resources when final art arrives; screen layouts do not need
to change.
