# Design guidelines

## Visual direction

- Use the shared semantic colours, spacing, radii and surfaces in
  `DesignSystem` so new screens remain consistent with the dark, premium court
  design.
- Team A (the app user's team) is blue and Team B (the opponent) is warm red.
  Scores should use these colours as accents without sacrificing legibility.
- Prefer clear hierarchy, restrained borders and rounded cards over decorative
  elements that do not communicate state or an action.
- Constrain image-backed cards to the width proposed by their container. Never
  let an image's intrinsic size determine a card's width; every screen must fit
  the narrowest supported iPhone in portrait without horizontal scrolling.
- On Mix format cards, keep the format label in tennis yellow near the top,
  inset far enough to avoid bright details in the artwork. Show the artwork at
  full brightness without a gradient or white action title over it.

## People and image assets

- **Do not create people, avatars, mascots or other human figures as SVG
  files.** SVG character artwork does not fit the desired graphical quality.
- Use high-quality raster artwork (PNG/HEIF) for illustrated people and
  photography. Use SF Symbols for interface icons.
- Existing non-character vector assets can remain vector-based when that is the
  clearest and most scalable format.
- Reuse the Americano and Mexicano Mix-card artwork on their setup screens; do
  not introduce separate national or political character mascots.

## Localization

- Write user-facing SwiftUI source strings in English and provide Danish in
  `Localizable.xcstrings`. Do not hard-code Danish in views. This lets iOS
  automatically show Danish when the device language is Danish and English
  otherwise.
