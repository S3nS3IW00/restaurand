# Restaurand
A restaurant randomizer that uses the Google Maps API and Geolocation service. It queries places with the “restaurant” type in the selected area (`v1/places:searchNearby`) and randomly selects one, displaying a nice radar effect. Users can navigate to a specific location either by using the Geolocation service to get their current position or by searching for a location in the search bar (`v1/places:search`).

> [!WARNING]
> The APIs used by this app are not free and require a billing account in Google Cloud.

## Build
Running the app requires a Google Maps API key, which can be obtained from the Google Cloud Console. Replace all instances of `<MAPS_API_KEY>` in the code with your API key.

## Preview
A working preview is available on [Github Pages](https://s3ns3iw00.github.io/restaurand)
