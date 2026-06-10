import { importLibrary, setOptions } from "@googlemaps/js-api-loader";
import { googleMapsApiKey } from "@/lib/google-maps-config";

const ADDRESS_PRIMARY_TYPES = new Set([
  "street_address",
  "route",
  "premise",
  "subpremise",
  "street_number",
  "intersection",
]);

const HOUSE_NUMBER_PATTERN = /\d+\s*[a-zA-Z]?/;

export type AddressSuggestion = {
  placeId: string;
  placePrediction: google.maps.places.PlacePrediction;
  primaryText: string;
  secondaryText: string;
  fullText: string;
  types: string[];
};

type PlacesLibrary = google.maps.PlacesLibrary;

let loaderPromise: Promise<PlacesLibrary> | null = null;
let optionsConfigured = false;

export function queryHasHouseNumber(query: string): boolean {
  return HOUSE_NUMBER_PATTERN.test(query);
}

function matchesStreetQuery(query: string, primaryText: string): boolean {
  const q = query.toLowerCase().trim();
  const p = primaryText.toLowerCase().trim();
  if (!q || !p) return false;
  if (p.startsWith(q) || q.startsWith(p)) return true;
  const pStreet = p.split(",")[0]?.trim() ?? "";
  const qStreet = q.split(",")[0]?.trim() ?? "";
  return pStreet.startsWith(qStreet) || qStreet.startsWith(pStreet);
}

function isAddressLike(types: string[], query: string, primaryText: string): boolean {
  if (types.length > 0) {
    return types.some((type) => ADDRESS_PRIMARY_TYPES.has(type));
  }
  return !queryHasHouseNumber(primaryText) && matchesStreetQuery(query, primaryText);
}

function looksLikeStreetWithoutNumber(types: string[], primaryText: string, fullText: string): boolean {
  if (queryHasHouseNumber(primaryText) || queryHasHouseNumber(fullText)) return false;
  if (types.length > 0) {
    if (types.includes("street_address") || types.includes("street_number")) return false;
    return types.includes("route");
  }
  return false;
}

function matchScore(query: string, text: string): number {
  const q = query.toLowerCase().trim();
  const t = text.toLowerCase();
  if (t.includes(q)) return 1000;

  let score = 0;
  for (const part of q.split(/\s+/)) {
    if (part.length >= 2 && t.includes(part)) score += 40;
  }

  const number = q.match(HOUSE_NUMBER_PATTERN)?.[0];
  if (number) {
    const normalized = number.replace(/\s+/g, "").toLowerCase();
    if (t.replace(/\s+/g, "").includes(normalized)) score += 200;
  }

  return score;
}

function rankSuggestions(items: AddressSuggestion[], query: string): AddressSuggestion[] {
  const hasNumber = queryHasHouseNumber(query);
  return [...items].sort((a, b) => {
    let scoreA = matchScore(query, a.fullText) + (isAddressLike(a.types, query, a.primaryText) ? 5 : 0);
    let scoreB = matchScore(query, b.fullText) + (isAddressLike(b.types, query, b.primaryText) ? 5 : 0);
    if (!hasNumber) {
      if (looksLikeStreetWithoutNumber(a.types, a.primaryText, a.fullText)) scoreA += 30;
      if (looksLikeStreetWithoutNumber(b.types, b.primaryText, b.fullText)) scoreB += 30;
    }
    return scoreB - scoreA;
  });
}

export function shouldOfferAddStreetNumber(suggestion: AddressSuggestion, query: string): boolean {
  if (queryHasHouseNumber(query)) return false;
  return looksLikeStreetWithoutNumber(
    suggestion.types,
    suggestion.primaryText,
    suggestion.fullText,
  ) || matchesStreetQuery(query, suggestion.primaryText);
}

export function streetNameFromSuggestion(suggestion: AddressSuggestion): string {
  const raw = suggestion.primaryText.trim();
  if (!raw) return raw;
  return raw.split(",")[0]?.trim() ?? raw;
}

export async function loadPlacesLibrary(): Promise<PlacesLibrary | null> {
  const apiKey = googleMapsApiKey();
  if (!apiKey) return null;

  if (!optionsConfigured) {
    setOptions({ key: apiKey, v: "weekly" });
    optionsConfigured = true;
  }

  loaderPromise ??= importLibrary("places").then((library) => library as PlacesLibrary);

  return loaderPromise;
}

export function locationBiasAround(origin: google.maps.LatLngLiteral, radiusDegrees = 0.45) {
  return {
    west: origin.lng - radiusDegrees,
    north: origin.lat + radiusDegrees,
    east: origin.lng + radiusDegrees,
    south: origin.lat - radiusDegrees,
  };
}

let cachedOrigin: google.maps.LatLngLiteral | null = null;
let originPromise: Promise<google.maps.LatLngLiteral | null> | null = null;

export function deviceLocationForPlaces(): Promise<google.maps.LatLngLiteral | null> {
  if (cachedOrigin) return Promise.resolve(cachedOrigin);
  if (originPromise) return originPromise;

  originPromise = new Promise<google.maps.LatLngLiteral | null>((resolve) => {
    if (typeof navigator === "undefined" || !navigator.geolocation) {
      resolve(null);
      return;
    }

    navigator.geolocation.getCurrentPosition(
      (position) => {
        cachedOrigin = {
          lat: position.coords.latitude,
          lng: position.coords.longitude,
        };
        resolve(cachedOrigin);
      },
      () => resolve(null),
      { enableHighAccuracy: false, maximumAge: 60_000, timeout: 8_000 },
    );
  }).finally(() => {
    originPromise = null;
  });

  return originPromise;
}

function toSuggestion(
  prediction: google.maps.places.PlacePrediction,
): AddressSuggestion | null {
  const placeId = prediction.placeId;
  if (!placeId) return null;

  const mainText = prediction.mainText?.text?.trim() ?? "";
  const secondaryText = prediction.secondaryText?.text?.trim() ?? "";
  const fullText = prediction.text?.text?.trim() ?? [mainText, secondaryText].filter(Boolean).join(", ");

  return {
    placeId,
    placePrediction: prediction,
    primaryText: mainText || fullText,
    secondaryText: secondaryText,
    fullText,
    types: prediction.types ?? [],
  };
}

export function messageForPlacesError(error: unknown): string | null {
  const text = error instanceof Error ? error.message : String(error);
  if (
    text.includes("AutocompletePlaces are blocked") ||
    text.includes("9011") ||
    text.includes("Places API (New)")
  ) {
    return "Address suggestions unavailable. Enable Places API (New) for your Google Maps key.";
  }
  return null;
}

export async function fetchAddressSuggestions(
  query: string,
  sessionToken: google.maps.places.AutocompleteSessionToken,
): Promise<AddressSuggestion[]> {
  const places = await loadPlacesLibrary();
  if (!places) return [];

  const origin = await deviceLocationForPlaces();
  const useLocation = origin != null && !queryHasHouseNumber(query);

  const request: google.maps.places.AutocompleteRequest = {
    input: query,
    sessionToken,
  };

  if (useLocation && origin) {
    request.origin = origin;
    request.locationBias = locationBiasAround(origin);
  }

  const { suggestions } = await places.AutocompleteSuggestion.fetchAutocompleteSuggestions(request);

  const mapped = suggestions
    .map((item) => (item.placePrediction ? toSuggestion(item.placePrediction) : null))
    .filter((item): item is AddressSuggestion => item != null);

  return rankSuggestions(mapped, query);
}

export async function fetchFormattedAddress(
  suggestion: AddressSuggestion,
): Promise<string> {
  try {
    const place = suggestion.placePrediction.toPlace();
    await place.fetchFields({
      fields: ["formattedAddress"],
    });
    const formatted = place.formattedAddress?.trim();
    if (formatted) return formatted;
  } catch {
    // Fall back to the suggestion text.
  }

  return suggestion.fullText;
}

export function createAutocompleteSessionToken(
  places: PlacesLibrary,
): google.maps.places.AutocompleteSessionToken {
  return new places.AutocompleteSessionToken();
}
