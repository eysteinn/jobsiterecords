/** Google Maps / Places API key for browser-side address autocomplete. */
export function googleMapsApiKey(): string | null {
  const key = process.env.NEXT_PUBLIC_GOOGLE_MAPS?.trim();
  if (!key) return null;
  return key;
}
