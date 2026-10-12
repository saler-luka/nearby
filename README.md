# Nearby

Find restaurants, cafés, bars and places to stay within walking distance of you, or of any town in Croatia.

- Search a town, or use your location, and pick a radius
- 3D map with walking times, cuisine, terraces, opening hours
- Reviews and photos open in Google Maps; online menus open in-app

Single-file app (`index.html`), no build step. Town search uses Photon, map tiles come from OpenFreeMap.

Place data comes from OpenStreetMap. For Croatia it is prebuilt into `data/` (small per-area files the app loads in well under a second) by the **Refresh place data** GitHub Action, which runs weekly: it downloads Geofabrik's Croatia extract, filters it with osmium and runs `build-data.ps1`. Outside Croatia the app falls back to the live Overpass API.

Run locally: `powershell -ExecutionPolicy Bypass -File serve.ps1`, then open http://localhost:5173.
