"use client";

import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useCallback, useEffect, useMemo, useState } from "react";
import { useDebouncedValue } from "@/hooks/use-debounced-value";

const DEBOUNCE_MS = 250;

function useStateSynced<T>(external: T): [T, (value: T) => void] {
  const [value, setValue] = useState(external);
  useEffect(() => {
    setValue(external);
  }, [external]);
  return [value, setValue];
}

export function useUrlQueryParam(key: string) {
  const searchParams = useSearchParams();
  const router = useRouter();
  const pathname = usePathname();

  const urlValue = searchParams.get(key) ?? "";
  const [draft, setDraft] = useStateSynced(urlValue);
  const debounced = useDebouncedValue(draft, DEBOUNCE_MS);

  const replaceParams = useCallback(
    (mutate: (params: URLSearchParams) => void) => {
      const params = new URLSearchParams(searchParams.toString());
      mutate(params);
      const next = params.toString();
      router.replace(next ? `${pathname}?${next}` : pathname, { scroll: false });
    },
    [pathname, router, searchParams],
  );

  useEffect(() => {
    const trimmed = debounced.trim();
    const current = searchParams.get(key) ?? "";
    if (trimmed === current) return;
    replaceParams((params) => {
      if (trimmed) params.set(key, trimmed);
      else params.delete(key);
    });
  }, [debounced, key, replaceParams, searchParams]);

  return [draft, setDraft] as const;
}

export function useUrlSetParam(key: string) {
  const searchParams = useSearchParams();
  const router = useRouter();
  const pathname = usePathname();

  const values = useMemo(() => {
    const raw = searchParams.get(key);
    if (!raw) return new Set<string>();
    return new Set(raw.split(",").filter(Boolean));
  }, [key, searchParams]);

  const setValues = useCallback(
    (next: Set<string>) => {
      const params = new URLSearchParams(searchParams.toString());
      if (next.size === 0) params.delete(key);
      else params.set(key, [...next].join(","));
      const qs = params.toString();
      router.replace(qs ? `${pathname}?${qs}` : pathname, { scroll: false });
    },
    [key, pathname, router, searchParams],
  );

  const toggle = useCallback(
    (id: string) => {
      const next = new Set(values);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      setValues(next);
    },
    [setValues, values],
  );

  return { values, setValues, toggle };
}
