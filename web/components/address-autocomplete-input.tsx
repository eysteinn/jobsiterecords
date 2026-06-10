"use client";

import {
  useCallback,
  useEffect,
  useId,
  useRef,
  useState,
  type KeyboardEvent,
} from "react";
import { googleMapsApiKey } from "@/lib/google-maps-config";
import {
  createAutocompleteSessionToken,
  fetchAddressSuggestions,
  fetchFormattedAddress,
  loadPlacesLibrary,
  messageForPlacesError,
  shouldOfferAddStreetNumber,
  streetNameFromSuggestion,
  type AddressSuggestion,
} from "@/lib/places-autocomplete";
import styles from "./job-form.module.css";

type Props = {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  id?: string;
};

export function AddressAutocompleteInput({ value, onChange, placeholder, id }: Props) {
  const generatedId = useId();
  const inputId = id ?? generatedId;
  const listboxId = `${inputId}-suggestions`;
  const hasApiKey = googleMapsApiKey() != null;

  const inputRef = useRef<HTMLInputElement>(null);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const sessionTokenRef = useRef<google.maps.places.AutocompleteSessionToken | null>(null);
  const requestIdRef = useRef(0);

  const [suggestions, setSuggestions] = useState<AddressSuggestion[]>([]);
  const [showSuggestions, setShowSuggestions] = useState(false);
  const [loading, setLoading] = useState(false);
  const [apiError, setApiError] = useState<string | null>(null);
  const [activeIndex, setActiveIndex] = useState(-1);

  const ensureSessionToken = useCallback(async () => {
    if (sessionTokenRef.current) return sessionTokenRef.current;
    const places = await loadPlacesLibrary();
    if (!places) return null;
    sessionTokenRef.current = createAutocompleteSessionToken(places);
    return sessionTokenRef.current;
  }, []);

  const resetSessionToken = useCallback(async () => {
    const places = await loadPlacesLibrary();
    if (!places) {
      sessionTokenRef.current = null;
      return;
    }
    sessionTokenRef.current = createAutocompleteSessionToken(places);
  }, []);

  const clearSuggestions = useCallback(() => {
    setSuggestions([]);
    setShowSuggestions(false);
    setActiveIndex(-1);
  }, []);

  const runQuery = useCallback(
    async (query: string) => {
      if (!hasApiKey || query.length < 2) {
        clearSuggestions();
        setLoading(false);
        setApiError(null);
        return;
      }

      const requestId = ++requestIdRef.current;
      setLoading(true);
      setApiError(null);

      try {
        const token = await ensureSessionToken();
        if (!token) {
          if (requestId === requestIdRef.current) {
            clearSuggestions();
            setLoading(false);
          }
          return;
        }

        const results = await fetchAddressSuggestions(query, token);
        if (requestId !== requestIdRef.current) return;

        setSuggestions(results);
        setShowSuggestions(results.length > 0);
        setActiveIndex(-1);
        setLoading(false);
      } catch (error) {
        if (requestId !== requestIdRef.current) return;
        clearSuggestions();
        setLoading(false);
        setApiError(messageForPlacesError(error));
      }
    },
    [clearSuggestions, ensureSessionToken, hasApiKey],
  );

  const scheduleQuery = useCallback(
    (query: string) => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
      debounceRef.current = setTimeout(() => {
        void runQuery(query);
      }, 300);
    },
    [runQuery],
  );

  useEffect(() => {
    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, []);

  const handleChange = (nextValue: string) => {
    onChange(nextValue);
    const query = nextValue.trim();
    if (query.length < 2) {
      if (debounceRef.current) clearTimeout(debounceRef.current);
      clearSuggestions();
      setLoading(false);
      setApiError(null);
      return;
    }
    scheduleQuery(query);
  };

  const selectSuggestion = async (suggestion: AddressSuggestion) => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    setShowSuggestions(false);
    setSuggestions([]);
    setLoading(true);

    const address = await fetchFormattedAddress(suggestion);

    onChange(address);
    setLoading(false);
    await resetSessionToken();
    inputRef.current?.blur();
  };

  const beginAddStreetNumber = (suggestion: AddressSuggestion) => {
    const street = streetNameFromSuggestion(suggestion);
    if (!street) return;

    const nextValue = `${street} `;
    onChange(nextValue);
    clearSuggestions();
    requestAnimationFrame(() => {
      inputRef.current?.focus();
      const len = nextValue.length;
      inputRef.current?.setSelectionRange(len, len);
    });
  };

  const handleKeyDown = (event: KeyboardEvent<HTMLInputElement>) => {
    if (!showSuggestions || suggestions.length === 0) return;

    if (event.key === "ArrowDown") {
      event.preventDefault();
      setActiveIndex((index) => (index + 1) % suggestions.length);
      return;
    }

    if (event.key === "ArrowUp") {
      event.preventDefault();
      setActiveIndex((index) => (index <= 0 ? suggestions.length - 1 : index - 1));
      return;
    }

    if (event.key === "Enter" && activeIndex >= 0) {
      event.preventDefault();
      void selectSuggestion(suggestions[activeIndex]!);
      return;
    }

    if (event.key === "Escape") {
      clearSuggestions();
    }
  };

  const query = value.trim();
  const addNumberIndex = suggestions.findIndex((item) => shouldOfferAddStreetNumber(item, query));

  if (!hasApiKey) {
    return (
      <input
        id={inputId}
        value={value}
        onChange={(event) => onChange(event.target.value)}
        placeholder={placeholder}
      />
    );
  }

  return (
    <div className={styles.addressField}>
      <div className={styles.addressInputWrap}>
        <input
          ref={inputRef}
          id={inputId}
          value={value}
          onChange={(event) => handleChange(event.target.value)}
          onFocus={() => {
            if (query.length >= 2 && suggestions.length > 0) {
              setShowSuggestions(true);
            } else if (query.length >= 2) {
              scheduleQuery(query);
            }
          }}
          onBlur={() => {
            window.setTimeout(() => setShowSuggestions(false), 150);
          }}
          onKeyDown={handleKeyDown}
          placeholder={placeholder}
          role="combobox"
          aria-expanded={showSuggestions}
          aria-controls={showSuggestions ? listboxId : undefined}
          aria-autocomplete="list"
          aria-activedescendant={
            activeIndex >= 0 ? `${inputId}-option-${activeIndex}` : undefined
          }
        />
        {loading && <span className={styles.addressSpinner} aria-hidden="true" />}
      </div>

      {apiError && <p className={styles.addressHint}>{apiError}</p>}

      {showSuggestions && suggestions.length > 0 && (
        <div className={styles.addressSuggestions} id={listboxId} role="listbox">
          {suggestions.map((suggestion, index) => {
            const showAddStreetNumber = index === addNumberIndex;
            const primary = showAddStreetNumber
              ? streetNameFromSuggestion(suggestion)
              : suggestion.primaryText;
            const secondary =
              suggestion.secondaryText ||
              (suggestion.primaryText.includes(",")
                ? suggestion.primaryText.slice(suggestion.primaryText.indexOf(",") + 1).trim()
                : "");

            return (
              <div key={suggestion.placeId} className={styles.addressSuggestionGroup}>
                <button
                  type="button"
                  id={`${inputId}-option-${index}`}
                  role="option"
                  aria-selected={index === activeIndex}
                  className={
                    index === activeIndex
                      ? `${styles.addressSuggestion} ${styles.addressSuggestionActive}`
                      : styles.addressSuggestion
                  }
                  onMouseDown={(event) => event.preventDefault()}
                  onClick={() => {
                    if (showAddStreetNumber) {
                      beginAddStreetNumber(suggestion);
                      return;
                    }
                    void selectSuggestion(suggestion);
                  }}
                >
                  <span className={styles.addressSuggestionIcon} aria-hidden="true">
                    {showAddStreetNumber ? "⌖" : "⌂"}
                  </span>
                  <span className={styles.addressSuggestionText}>
                    <span className={styles.addressSuggestionPrimary}>{primary}</span>
                    {secondary ? (
                      <span className={styles.addressSuggestionSecondary}>{secondary}</span>
                    ) : null}
                  </span>
                </button>
                {showAddStreetNumber ? (
                  <button
                    type="button"
                    className={styles.addressAddNumber}
                    onMouseDown={(event) => event.preventDefault()}
                    onClick={() => beginAddStreetNumber(suggestion)}
                  >
                    + Add street number
                  </button>
                ) : null}
              </div>
            );
          })}
          <div className={styles.addressAttribution}>
            <img
              src="https://developers.google.com/static/maps/documentation/images/powered_by_google_on_white.png"
              alt="Powered by Google"
              width={120}
              height={16}
            />
          </div>
        </div>
      )}
    </div>
  );
}
