# App branding

- `wc26_logo_source.png` — stacked **20 / 26** mark (FIFA WC26 year-style background).
- `wc26_logo.png` — transparent in-app mark (256px).
- `wc26_cup.png` — World Cup trophy for the Home hero.
- `panini_cover_side_left.png` / `panini_cover_side_right.png` — interlocking colorful “26” strips cropped from the Panini album cover.
- `app_icon.png` / `app_icon_foreground.png` — launcher icons from `tooling/generate_app_icon.py`.
- `amenti_logo_mark.svg` / `amenti_logo_mark.png` — Amenti Labs mark for Settings.

Regenerate after updating the WC26 source:

```bash
python3 tooling/generate_app_icon.py
dart run flutter_launcher_icons
```
