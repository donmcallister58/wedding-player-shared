# Adding a track to the catalogue

When a new piece of music is licensed/recorded for the catalogue.

## Steps

1. **Drop the master MP3** into Google Drive at:
   ```
   ~/Library/CloudStorage/GoogleDrive-don@playerapps.uk/My Drive/Wedding Player Catalogue Assets/tracks/wp_NNN.mp3
   ```
   Use the next sequential number (current highest is `wp_036`).

2. **Stub a manifest entry** in `catalogue/catalogue.json`:
   ```json
   {
     "id": "wp_037",
     "title": "<Track title>",
     "style": "<Style description>",
     "category": "PRELUDE | PROCESSIONAL | SIGNING | RECESSIONAL",
     "durationSecs": 0,
     "filename": "wp_037.mp3"
   }
   ```
   `sourceHash` and `previewVersion` will be filled in by the next step.

3. **Generate previews** (also fills in sourceHash + previewVersion + actual duration):
   ```bash
   ./scripts/generate-previews.sh \
     --source "/Users/donmcallister/Library/CloudStorage/GoogleDrive-don@playerapps.uk/My Drive/Wedding Player Catalogue Assets/tracks"
   ```

4. **Sync masters + previews to the CDN:**
   ```bash
   ./scripts/sync-to-cdn.sh wp_037   # placeholder script — wire up actual upload
   ```

5. **Commit + tag** a PATCH release:
   ```bash
   git add catalogue/catalogue.json catalogue/previews/wp_037.mp3
   git commit -m "Add track wp_037: <Title>"
   echo 1.0.1 > VERSION  # or next patch
   # update CHANGELOG.md under ## Unreleased then move to versioned heading
   git tag v1.0.1
   git push origin main --tags
   ```

6. **Bump iOS submodule** to the new tag, ship iOS.

7. **After iOS is on App Store**, bump Android submodule to the same tag, ship Android.
